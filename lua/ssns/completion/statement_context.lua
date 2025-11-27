---Statement-based context detection for SQL completion
---Uses StatementCache/StatementChunk exclusively (no tree-sitter)
local Debug = require('ssns.debug')
local StatementCache = require('ssns.completion.statement_cache')

local Context = {}

---Context types
Context.Type = {
  UNKNOWN = "unknown",
  KEYWORD = "keyword",
  DATABASE = "database",
  SCHEMA = "schema",
  TABLE = "table",
  COLUMN = "column",
  PROCEDURE = "procedure",
  PARAMETER = "parameter",
  ALIAS = "alias",
}

---Check if position is inside a SQL comment
---@param line string Full line text
---@param col number 1-indexed column
---@return boolean
function Context._is_in_comment(line, col)
  local before_cursor = line:sub(1, col - 1)

  -- Check for line comment --
  if before_cursor:match("%-%-") then
    return true
  end

  -- Check for block comment /* */
  -- Count opening and closing block comments
  local open_count = 0
  local close_count = 0
  for _ in before_cursor:gmatch("/%*") do
    open_count = open_count + 1
  end
  for _ in before_cursor:gmatch("%*/") do
    close_count = close_count + 1
  end

  return open_count > close_count
end

---Check if position is inside a string literal
---@param line string Full line text
---@param col number 1-indexed column
---@return boolean
function Context._is_in_string(line, col)
  local before_cursor = line:sub(1, col - 1)

  -- Count single quotes before cursor
  -- Ignore escaped quotes ('')
  local text_no_escaped = before_cursor:gsub("''", "")
  local quote_count = 0
  for _ in text_no_escaped:gmatch("'") do
    quote_count = quote_count + 1
  end

  -- Odd number of quotes means we're inside a string
  return quote_count % 2 == 1
end

---Extract prefix and trigger character before cursor
---@param line string Full line text
---@param col number 1-indexed column
---@return string prefix The word/text before cursor
---@return string? trigger Trigger character (".", "[", " ", or nil)
function Context._extract_prefix_and_trigger(line, col)
  local before_cursor = line:sub(1, col - 1)

  -- Check for trigger characters at cursor position
  local trigger = nil
  if before_cursor:sub(-1) == "." then
    trigger = "."
  elseif before_cursor:sub(-1) == "[" then
    trigger = "["
  elseif before_cursor:sub(-1) == " " then
    trigger = " "
  end

  -- Extract the word before cursor
  -- Match identifier characters: alphanumeric, underscore, #, @
  local prefix = before_cursor:match("([%w_#@%.%[%]]+)$") or ""

  return prefix, trigger
end

---Get reference before a dot (e.g., "e." -> "e", "dbo.Employees." -> "dbo.Employees")
---@param before_cursor string Text before cursor
---@return string? reference The table/alias reference, or nil
function Context._get_reference_before_dot(before_cursor)
  -- Remove the trailing dot
  if before_cursor:sub(-1) == "." then
    before_cursor = before_cursor:sub(1, -2)
  end

  -- Match the reference before the dot
  -- Can be: identifier, or schema.table, or database.schema.table
  -- Match pattern: [bracket_id] or identifier or qualified.name
  local ref = before_cursor:match("([%w_%.%[%]]+)$")
  if ref then
    -- Clean up any whitespace
    ref = ref:gsub("%s+", "")
    return ref
  end

  return nil
end

---Parse qualified name into parts
---@param before_cursor string Text before cursor
---@return {database: string?, schema: string?, table: string?, alias: string?}
function Context._parse_qualified_name(before_cursor)
  local parts = {}

  -- Split by dots
  for part in before_cursor:gmatch("[^%.]+") do
    -- Remove brackets if present
    part = part:gsub("^%[", ""):gsub("%]$", "")
    table.insert(parts, part)
  end

  local result = {
    database = nil,
    schema = nil,
    table = nil,
    alias = nil,
  }

  if #parts == 1 then
    result.alias = parts[1]
  elseif #parts == 2 then
    result.schema = parts[1]
    result.table = parts[2]
  elseif #parts == 3 then
    result.database = parts[1]
    result.schema = parts[2]
    result.table = parts[3]
  elseif #parts >= 4 then
    -- 4-part name: server.database.schema.table (ignore server for now)
    result.database = parts[2]
    result.schema = parts[3]
    result.table = parts[4]
  end

  return result
end

---Detect context type from line text before cursor
---@param before_cursor string Text before cursor (trimmed)
---@param chunk StatementChunk? The parsed chunk
---@return string type Context type from Context.Type
---@return string mode Sub-mode for provider routing
---@return table extra_info Extra context info (table_ref, schema, database, etc.)
function Context._detect_type_from_line(before_cursor, chunk)
  local upper = before_cursor:upper()
  local extra = {}

  -- Remove leading/trailing whitespace for pattern matching
  local trimmed = before_cursor:match("^%s*(.-)%s*$") or ""
  local upper_trimmed = trimmed:upper()

  -- Check for qualified column reference (alias.column, table.column)
  if before_cursor:match("%.%s*$") or before_cursor:match("%.[%w_]*$") then
    local ref = Context._get_reference_before_dot(before_cursor)
    if ref then
      extra.table_ref = ref
      extra.filter_table = ref
      extra.omit_table = true
      return Context.Type.COLUMN, "qualified", extra
    end
  end

  -- TABLE contexts
  if upper_trimmed:match("FROM%s+$") or upper:match("FROM%s+[%w_#@%.%[%]]*$") then
    -- Check for qualified table after FROM
    local after_from = trimmed:match("FROM%s+(.*)$")
    if after_from then
      local qualified = Context._parse_qualified_name(after_from)
      if qualified.database then
        extra.database = qualified.database
        extra.schema = qualified.schema
        return Context.Type.TABLE, "from_cross_db_qualified", extra
      elseif qualified.schema then
        extra.schema = qualified.schema
        return Context.Type.TABLE, "from_qualified", extra
      end
    end
    return Context.Type.TABLE, "from", extra
  end

  if upper_trimmed:match("JOIN%s+$") or upper:match("JOIN%s+[%w_#@%.%[%]]*$") then
    -- Check for qualified table after JOIN
    local after_join = trimmed:match("JOIN%s+(.*)$")
    if after_join then
      local qualified = Context._parse_qualified_name(after_join)
      if qualified.database then
        extra.database = qualified.database
        extra.schema = qualified.schema
        return Context.Type.TABLE, "join_cross_db_qualified", extra
      elseif qualified.schema then
        extra.schema = qualified.schema
        return Context.Type.TABLE, "join_qualified", extra
      end
    end
    return Context.Type.TABLE, "join", extra
  end

  -- Handle JOIN modifiers (INNER JOIN, LEFT JOIN, etc.)
  if upper_trimmed:match("INNER%s+JOIN%s+$") or upper_trimmed:match("LEFT%s+JOIN%s+$") or
     upper_trimmed:match("RIGHT%s+JOIN%s+$") or upper_trimmed:match("FULL%s+JOIN%s+$") or
     upper_trimmed:match("CROSS%s+JOIN%s+$") or upper_trimmed:match("OUTER%s+JOIN%s+$") then
    return Context.Type.TABLE, "join", extra
  end

  if upper_trimmed:match("UPDATE%s+$") or upper:match("UPDATE%s+[%w_#@%.%[%]]*$") then
    return Context.Type.TABLE, "update", extra
  end

  if upper_trimmed:match("DELETE%s+FROM%s+$") or upper:match("DELETE%s+FROM%s+[%w_#@%.%[%]]*$") then
    return Context.Type.TABLE, "delete", extra
  end

  if upper_trimmed:match("INSERT%s+INTO%s+$") or upper:match("INSERT%s+INTO%s+[%w_#@%.%[%]]*$") then
    return Context.Type.TABLE, "insert", extra
  end

  -- Check for database.schema. pattern in table context
  if upper:match("[%w_]+%.[%w_]*%.$") then
    -- This could be schema.table. or database.schema.
    -- Count dots to determine
    local dot_count = 0
    for _ in before_cursor:gmatch("%.") do
      dot_count = dot_count + 1
    end

    if dot_count == 1 then
      -- schema.| -> complete tables
      local schema = before_cursor:match("([%w_]+)%.")
      extra.schema = schema
      extra.filter_schema = schema
      return Context.Type.TABLE, "from_qualified", extra
    elseif dot_count >= 2 then
      -- database.schema.| -> complete tables
      local parts = Context._parse_qualified_name(before_cursor:sub(1, -2))
      extra.database = parts.database
      extra.schema = parts.schema
      return Context.Type.TABLE, "from_cross_db_qualified", extra
    end
  end

  -- COLUMN contexts
  if upper_trimmed:match("SELECT%s+$") or (upper:match("SELECT%s+") and not upper:match("FROM")) then
    return Context.Type.COLUMN, "select", extra
  end

  if upper_trimmed:match("WHERE%s+$") or upper:match("WHERE%s+[%w_%.]*$") then
    return Context.Type.COLUMN, "where", extra
  end

  if upper_trimmed:match("AND%s+$") or upper_trimmed:match("OR%s+$") then
    -- Could be in WHERE clause
    return Context.Type.COLUMN, "where", extra
  end

  if upper_trimmed:match("ON%s+$") or upper:match("ON%s+[%w_%.]*$") then
    return Context.Type.COLUMN, "on", extra
  end

  if upper_trimmed:match("SET%s+$") or upper:match("SET%s+[%w_%.]*$") then
    -- UPDATE SET clause
    if chunk and chunk.statement_type == "UPDATE" then
      return Context.Type.COLUMN, "set", extra
    end
  end

  if upper_trimmed:match("ORDER%s+BY%s+$") or upper:match("ORDER%s+BY%s+[%w_%.]*$") then
    return Context.Type.COLUMN, "order_by", extra
  end

  if upper_trimmed:match("GROUP%s+BY%s+$") or upper:match("GROUP%s+BY%s+[%w_%.]*$") then
    return Context.Type.COLUMN, "group_by", extra
  end

  if upper_trimmed:match("HAVING%s+$") or upper:match("HAVING%s+[%w_%.]*$") then
    return Context.Type.COLUMN, "having", extra
  end

  -- PROCEDURE contexts
  if upper_trimmed:match("EXEC%s+$") or upper_trimmed:match("EXECUTE%s+$") or
     upper:match("EXEC%s+[%w_%.]*$") or upper:match("EXECUTE%s+[%w_%.]*$") then
    return Context.Type.PROCEDURE, "exec", extra
  end

  -- DATABASE contexts
  if upper_trimmed:match("USE%s+$") or upper:match("USE%s+[%w_]*$") then
    return Context.Type.DATABASE, "use", extra
  end

  -- SCHEMA context (after database.)
  if upper:match("USE%s+[%w_]+%.$") then
    local db = before_cursor:match("USE%s+([%w_]+)%.")
    extra.database = db
    return Context.Type.SCHEMA, "cross_db", extra
  end

  -- KEYWORD context (default fallback)
  -- At start of line/statement or after common terminators
  if trimmed == "" or upper_trimmed:match("^%s*$") then
    return Context.Type.KEYWORD, "start", extra
  end

  -- After semicolon or GO
  if upper_trimmed:match(";%s*$") or upper_trimmed:match("GO%s*$") then
    return Context.Type.KEYWORD, "start", extra
  end

  return Context.Type.KEYWORD, "general", extra
end

---Main context detection (simple version without full checks)
---@param bufnr number Buffer number
---@param line_num number 1-indexed line number
---@param col number 1-indexed column
---@return table context Context information
function Context.detect(bufnr, line_num, col)
  Debug.log(string.format("[statement_context] detect: bufnr=%d, line=%d, col=%d", bufnr, line_num, col))

  -- Get line text
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
  if #lines == 0 then
    return {
      type = Context.Type.UNKNOWN,
      mode = "unknown",
      prefix = "",
      trigger = nil,
      chunk = nil,
      tables = {},
      aliases = {},
      ctes = {},
      temp_tables = {},
      subquery = nil,
    }
  end

  local line = lines[1]
  local before_cursor = line:sub(1, col - 1)

  -- Get StatementCache context
  local cache_ctx = StatementCache.get_context_at_position(bufnr, line_num, col)

  -- Extract prefix and trigger
  local prefix, trigger = Context._extract_prefix_and_trigger(line, col)

  -- Detect type using clause positions first, fallback to line-based detection
  local ctx_type, mode, extra
  local chunk = cache_ctx and cache_ctx.chunk

  if chunk then
    local StatementParser = require('ssns.completion.statement_parser')
    local clause = StatementParser.get_clause_at_position(chunk, line_num, col)

    if clause then
      -- Use clause position to determine context
      extra = {}
      if clause == "select" then
        ctx_type = Context.Type.COLUMN
        mode = "select"
      elseif clause == "from" then
        ctx_type = Context.Type.TABLE
        mode = "from"
      elseif clause == "join" then
        ctx_type = Context.Type.TABLE
        mode = "join"
      elseif clause == "on" then
        ctx_type = Context.Type.COLUMN
        mode = "on"
      elseif clause == "where" then
        ctx_type = Context.Type.COLUMN
        mode = "where"
      elseif clause == "group_by" then
        ctx_type = Context.Type.COLUMN
        mode = "group_by"
      elseif clause == "having" then
        ctx_type = Context.Type.COLUMN
        mode = "having"
      elseif clause == "order_by" then
        ctx_type = Context.Type.COLUMN
        mode = "order_by"
      elseif clause == "set" then
        ctx_type = Context.Type.COLUMN
        mode = "set"
      elseif clause == "into" then
        ctx_type = Context.Type.TABLE
        mode = "into"
      elseif clause == "insert_columns" then
        ctx_type = Context.Type.COLUMN
        mode = "insert_columns"
      end

      -- Check for qualified column reference (alias.column, table.column)
      if before_cursor:match("%.%s*$") or before_cursor:match("%.[%w_]*$") then
        local ref = Context._get_reference_before_dot(before_cursor)
        if ref then
          extra.table_ref = ref
          extra.filter_table = ref
          extra.omit_table = true
          ctx_type = Context.Type.COLUMN
          mode = "qualified"
        end
      end
    else
      -- Fallback to line-based detection
      ctx_type, mode, extra = Context._detect_type_from_line(before_cursor, chunk)
    end
  else
    -- No chunk, use line-based detection
    ctx_type, mode, extra = Context._detect_type_from_line(before_cursor, chunk)
  end

  -- Build context result
  local context = {
    type = ctx_type,
    mode = mode,
    prefix = prefix,
    trigger = trigger,

    -- Pass through StatementCache data
    chunk = cache_ctx and cache_ctx.chunk,
    tables = cache_ctx and cache_ctx.tables or {},
    aliases = cache_ctx and cache_ctx.aliases or {},
    ctes = cache_ctx and cache_ctx.ctes or {},
    temp_tables = cache_ctx and cache_ctx.temp_tables or {},
    subquery = cache_ctx and cache_ctx.subquery,

    -- Extra context from type detection
    table_ref = extra.table_ref,
    schema = extra.schema,
    database = extra.database,
    filter_schema = extra.filter_schema,
    filter_table = extra.filter_table,
    omit_schema = extra.omit_schema,
    omit_table = extra.omit_table,
  }

  Debug.log(string.format("[statement_context] detected type=%s, mode=%s, prefix=%s", ctx_type, mode, prefix))

  return context
end

---Full context detection with all checks (entry point for blink.cmp)
---@param bufnr number Buffer number
---@param line_num number 1-indexed line number
---@param col number 1-indexed column
---@return table context Full context with should_complete flag
function Context.detect_full(bufnr, line_num, col)
  Debug.log(string.format("[statement_context] detect_full: bufnr=%d, line=%d, col=%d", bufnr, line_num, col))

  -- Get line text
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
  if #lines == 0 then
    return {
      type = Context.Type.UNKNOWN,
      mode = "unknown",
      prefix = "",
      trigger = nil,
      should_complete = false,
      line = "",
      line_num = line_num,
      col = col,
      chunk = nil,
      tables = {},
      aliases = {},
      ctes = {},
      temp_tables = {},
      subquery = nil,
    }
  end

  local line = lines[1]

  -- Check if in comment or string
  if Context._is_in_comment(line, col) then
    Debug.log("[statement_context] Inside comment, skipping completion")
    return {
      type = Context.Type.UNKNOWN,
      mode = "comment",
      prefix = "",
      trigger = nil,
      should_complete = false,
      line = line,
      line_num = line_num,
      col = col,
      chunk = nil,
      tables = {},
      aliases = {},
      ctes = {},
      temp_tables = {},
      subquery = nil,
    }
  end

  if Context._is_in_string(line, col) then
    Debug.log("[statement_context] Inside string, skipping completion")
    return {
      type = Context.Type.UNKNOWN,
      mode = "string",
      prefix = "",
      trigger = nil,
      should_complete = false,
      line = line,
      line_num = line_num,
      col = col,
      chunk = nil,
      tables = {},
      aliases = {},
      ctes = {},
      temp_tables = {},
      subquery = nil,
    }
  end

  -- Get basic context
  local context = Context.detect(bufnr, line_num, col)

  -- Add full check fields
  context.should_complete = context.type ~= Context.Type.UNKNOWN
  context.line = line
  context.line_num = line_num
  context.col = col

  Debug.log(string.format("[statement_context] detect_full result: should_complete=%s, type=%s, mode=%s",
    tostring(context.should_complete), context.type, context.mode))

  return context
end

return Context
