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
  local has_trailing_dot = before_cursor:match("%.$") ~= nil

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

  -- Adjust interpretation based on trailing dot (completion context)
  if has_trailing_dot then
    -- Trailing dot means we're completing the NEXT level
    if #parts == 1 then
      -- "schema." -> complete tables in schema
      result.schema = parts[1]
    elseif #parts == 2 then
      -- "database.schema." -> complete tables in database.schema
      result.database = parts[1]
      result.schema = parts[2]
    elseif #parts >= 3 then
      -- "server.database.schema." -> complete tables (ignore server)
      result.database = parts[2]
      result.schema = parts[3]
    end
  else
    -- No trailing dot - original behavior for complete references
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
  end

  return result
end

---Extract the left-side column from a comparison expression
---Parses patterns like "t1.col = " or "column >= " from before cursor
---@param before_cursor string The text before the cursor
---@return table|nil left_side {qualified: string, table_ref: string|nil, column_name: string}
local function extract_left_side_column(before_cursor)
  if not before_cursor then return nil end

  -- Match qualified: "alias.column = " or "schema.table.column = "
  local qualified = before_cursor:match("([%w_%.%[%]]+)%s*[=<>!]+%s*$")

  -- Also try matching after AND/OR: "AND alias.column = "
  if not qualified then
    qualified = before_cursor:match("[Aa][Nn][Dd]%s+([%w_%.%[%]]+)%s*[=<>!]+%s*$")
  end
  if not qualified then
    qualified = before_cursor:match("[Oo][Rr]%s+([%w_%.%[%]]+)%s*[=<>!]+%s*$")
  end

  if not qualified then return nil end

  -- Strip brackets if present: [column] -> column
  qualified = qualified:gsub("%[", ""):gsub("%]", "")

  -- Split by dots
  local parts = {}
  for part in qualified:gmatch("[^%.]+") do
    table.insert(parts, part)
  end

  if #parts == 0 then return nil end

  -- Build result
  if #parts == 1 then
    -- Unqualified column: "column = "
    return {
      qualified = qualified,
      table_ref = nil,
      column_name = parts[1],
    }
  elseif #parts == 2 then
    -- Qualified: "alias.column = " or "table.column = "
    return {
      qualified = qualified,
      table_ref = parts[1],
      column_name = parts[2],
    }
  elseif #parts >= 3 then
    -- Schema qualified: "schema.table.column = "
    return {
      qualified = qualified,
      table_ref = parts[#parts - 1],  -- table
      column_name = parts[#parts],     -- column
      schema = parts[#parts - 2],      -- schema
    }
  end

  return nil
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

  -- TABLE contexts (CHECK THESE FIRST before dot pattern)
  if upper_trimmed:match("FROM%s+$") or upper:match("FROM%s+[%w_#@%.%[%]]*$") then
    -- Check for qualified table after FROM
    local after_from = trimmed:match("FROM%s+(.*)$")
    if after_from then
      local qualified = Context._parse_qualified_name(after_from)
      if qualified.database then
        extra.database = qualified.database
        extra.schema = qualified.schema
        extra.filter_database = qualified.database
        extra.filter_schema = qualified.schema
        extra.omit_schema = true
        return Context.Type.TABLE, "from_cross_db_qualified", extra
      elseif qualified.schema then
        -- Could be "schema." or "database." - set potential_database for provider to check
        extra.potential_database = qualified.schema
        extra.schema = qualified.schema
        extra.filter_schema = qualified.schema
        extra.omit_schema = true
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
        extra.filter_database = qualified.database
        extra.filter_schema = qualified.schema
        extra.omit_schema = true
        return Context.Type.TABLE, "join_cross_db_qualified", extra
      elseif qualified.schema then
        -- Could be "schema." or "database." - set potential_database for provider to check
        extra.potential_database = qualified.schema
        extra.schema = qualified.schema
        extra.filter_schema = qualified.schema
        extra.omit_schema = true
        return Context.Type.TABLE, "join_qualified", extra
      end
    end
    return Context.Type.TABLE, "join", extra
  end

  -- Handle JOIN modifiers (INNER JOIN, LEFT JOIN, etc.)
  -- Check both trimmed (ends with JOIN) and untrimmed (ends with JOIN + space)
  if upper_trimmed:match("INNER%s+JOIN$") or upper:match("INNER%s+JOIN%s+$") or
     upper_trimmed:match("LEFT%s+JOIN$") or upper:match("LEFT%s+JOIN%s+$") or
     upper_trimmed:match("LEFT%s+OUTER%s+JOIN$") or upper:match("LEFT%s+OUTER%s+JOIN%s+$") or
     upper_trimmed:match("RIGHT%s+JOIN$") or upper:match("RIGHT%s+JOIN%s+$") or
     upper_trimmed:match("RIGHT%s+OUTER%s+JOIN$") or upper:match("RIGHT%s+OUTER%s+JOIN%s+$") or
     upper_trimmed:match("FULL%s+JOIN$") or upper:match("FULL%s+JOIN%s+$") or
     upper_trimmed:match("FULL%s+OUTER%s+JOIN$") or upper:match("FULL%s+OUTER%s+JOIN%s+$") or
     upper_trimmed:match("CROSS%s+JOIN$") or upper:match("CROSS%s+JOIN%s+$") or
     upper_trimmed:match("OUTER%s+JOIN$") or upper:match("OUTER%s+JOIN%s+$") then
    return Context.Type.TABLE, "join", extra
  end

  -- UPDATE/DELETE/MERGE checks - must come BEFORE qualified column check
  -- so that "UPDATE dbo.█" is recognized as TABLE context, not COLUMN
  if upper_trimmed:match("UPDATE%s+$") or upper:match("UPDATE%s+[%w_#@%.%[%]]*$") then
    return Context.Type.TABLE, "update", extra
  end

  if upper_trimmed:match("DELETE%s+FROM%s+$") or upper:match("DELETE%s+FROM%s+[%w_#@%.%[%]]*$") then
    return Context.Type.TABLE, "delete", extra
  end

  -- DELETE without FROM is valid T-SQL: DELETE table or DELETE dbo.table
  if upper_trimmed:match("DELETE%s+$") or upper:match("DELETE%s+[%w_#@%.%[%]]*$") then
    return Context.Type.TABLE, "delete", extra
  end

  -- MERGE INTO target_table: MERGE INTO table AS target
  if upper_trimmed:match("MERGE%s+INTO%s+$") or upper:match("MERGE%s+INTO%s+[%w_#@%.%[%]]*$") then
    return Context.Type.TABLE, "merge", extra
  end

  -- MERGE USING source_table: MERGE ... USING table AS source
  if upper_trimmed:match("USING%s+$") or upper:match("USING%s+[%w_#@%.%[%]]*$") then
    return Context.Type.TABLE, "merge", extra
  end

  -- Check for qualified column reference (alias.column, table.column)
  -- This check comes AFTER FROM/JOIN/UPDATE/DELETE/MERGE checks to avoid
  -- misinterpreting "FROM dbo." or "UPDATE dbo." as a column reference
  if before_cursor:match("%.%s*$") or before_cursor:match("%.[%w_]*$") then
    local ref = Context._get_reference_before_dot(before_cursor)
    if ref then
      extra.table_ref = ref
      extra.filter_table = ref
      extra.omit_table = true
      return Context.Type.COLUMN, "qualified", extra
    end
  end

  -- VALUES clause context: INSERT INTO table (...) VALUES (val1, |val2)
  -- Need to count commas to determine which column position we're in
  local values_match = before_cursor:match("VALUES%s*%((.*)$")
  if values_match then
    -- Count commas to determine value position (which column we're inserting into)
    -- Handle nested parens (e.g., function calls) by tracking paren depth
    local value_position = 0
    local paren_depth = 0

    for char in values_match:gmatch(".") do
      if char == "(" then
        paren_depth = paren_depth + 1
      elseif char == ")" then
        paren_depth = paren_depth - 1
      elseif char == "," and paren_depth == 0 then
        value_position = value_position + 1
      end
    end

    extra.value_position = value_position
    return Context.Type.COLUMN, "values", extra
  end

  -- Also handle multi-row VALUES: VALUES (...), (|
  -- Reset position to 0 for new row
  local multi_row_match = before_cursor:match("VALUES[^%(]*%([^%)]*%)%s*,%s*%((.*)$")
  if multi_row_match then
    local value_position = 0
    local paren_depth = 0

    for char in multi_row_match:gmatch(".") do
      if char == "(" then
        paren_depth = paren_depth + 1
      elseif char == ")" then
        paren_depth = paren_depth - 1
      elseif char == "," and paren_depth == 0 then
        value_position = value_position + 1
      end
    end

    extra.value_position = value_position
    return Context.Type.COLUMN, "values", extra
  end

  -- INSERT INTO table ( column list: INSERT INTO Employees (█ or INSERT INTO Employees (col1, █
  -- This must come BEFORE INSERT INTO table check to detect column list context
  local insert_columns_match = before_cursor:match("[Ii][Nn][Ss][Ee][Rr][Tt]%s+[Ii][Nn][Tt][Oo]%s+([%w_%[%]%.]+)%s*%(")
  if insert_columns_match then
    -- Extract table name (handles schema.table and bracketed names)
    local table_name = insert_columns_match:gsub("^%[", ""):gsub("%]$", "")
    -- Handle schema-qualified names
    if table_name:match("%.") then
      local parts = {}
      for part in table_name:gmatch("[^%.]+") do
        -- Note: Use parentheses to discard the second return value from gsub (count)
        table.insert(parts, (part:gsub("^%[", ""):gsub("%]$", "")))
      end
      if #parts >= 2 then
        extra.schema = parts[#parts - 1]
        extra.table = parts[#parts]
      else
        extra.table = parts[1]
      end
    else
      extra.table = table_name
    end
    extra.insert_table = extra.table
    extra.insert_schema = extra.schema
    return Context.Type.COLUMN, "insert_columns", extra
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
  -- Check before_cursor for SELECT context (not full line - handles nested SELECT ... FROM)
  local before_upper = before_cursor:upper()
  if upper_trimmed:match("SELECT%s+$") or (before_upper:match("SELECT%s+") and not before_upper:match("FROM")) then
    return Context.Type.COLUMN, "select", extra
  end

  if upper_trimmed:match("WHERE%s+$") or upper:match("WHERE%s+[%w_%.]*$") then
    -- Check if we're after a comparison operator
    local left_side = extract_left_side_column(before_cursor)
    if left_side then
      extra.left_side = left_side
    end
    return Context.Type.COLUMN, "where", extra
  end

  if upper:match("AND%s+$") or upper:match("OR%s+$") or
     upper_trimmed:match("AND$") or upper_trimmed:match("OR$") then
    -- Could be in WHERE clause
    return Context.Type.COLUMN, "where", extra
  end

  if upper_trimmed:match("ON%s+$") or upper:match("ON%s+[%w_%.]*$") then
    local left_side = extract_left_side_column(before_cursor)
    if left_side then
      extra.left_side = left_side
    end
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

  -- Multiline fallback: Check chunk.statement_type for UPDATE/DELETE/MERGE statements
  -- This handles cases like "UPDATE\n  █" where the current line is empty/whitespace
  -- but we're still waiting for the table name
  if chunk then
    if chunk.statement_type == "UPDATE" and (not chunk.update_target or not chunk.update_target.name) then
      return Context.Type.TABLE, "update", extra
    elseif chunk.statement_type == "DELETE" and #(chunk.tables or {}) == 0 then
      return Context.Type.TABLE, "delete", extra
    elseif chunk.statement_type == "MERGE" and #(chunk.tables or {}) == 0 then
      return Context.Type.TABLE, "merge", extra
    end
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
  -- Pre-compute upper case version of before_cursor for pattern matching
  -- Must be declared before any goto statements to avoid scope issues
  local upper = before_cursor:upper()

  -- Special case: INSERT column list detection (incomplete parens case)
  -- Must check BEFORE clause-based routing because incomplete INSERT INTO table (
  -- returns "into" clause but we need "insert_columns" context
  local insert_columns_match = before_cursor:match("[Ii][Nn][Ss][Ee][Rr][Tt]%s+[Ii][Nn][Tt][Oo]%s+([%w_%[%]%.]+)%s*%(")
  if insert_columns_match then
    extra = {}
    local table_name = insert_columns_match:gsub("^%[", ""):gsub("%]$", "")
    if table_name:match("%.") then
      local parts = {}
      for part in table_name:gmatch("[^%.]+") do
        -- Note: Use parentheses to discard the second return value from gsub (count)
        -- otherwise table.insert interprets it as a position argument
        table.insert(parts, (part:gsub("^%[", ""):gsub("%]$", "")))
      end
      if #parts >= 2 then
        extra.schema = parts[#parts - 1]
        extra.table = parts[#parts]
      else
        extra.table = parts[1]
      end
    else
      extra.table = table_name
    end
    extra.insert_table = extra.table
    extra.insert_schema = extra.schema
    ctx_type = Context.Type.COLUMN
    mode = "insert_columns"
    -- Skip clause-based routing, jump to final context building
    goto build_context
  end

  -- Special case: ON clause detection
  -- Must check BEFORE clause-based routing because ON is not tracked separately
  -- by StatementParser - it's considered part of FROM clause
  -- Patterns: "... ON █" or "... ON alias.█" or "... ON col1 = █"
  if upper:match("%s+ON%s+$") or
     upper:match("%s+ON%s+[%w_%.]+$") or
     upper:match("%s+ON%s+[%w_%.]+%s*[=<>!]+%s*$") or
     upper:match("%s+ON%s+[%w_%.]+%s*[=<>!]+%s*[%w_%.]*$") or
     upper:match("%s+ON%s+[%w_%.]+%s+AND%s+$") or
     upper:match("%s+ON%s+[%w_%.]+%s*[=<>!]+%s*[%w_%.]+%s+AND%s+$") or
     upper:match("%s+ON%s+[%w_%.]+%s+AND%s+[%w_%.]*$") or
     upper:match("%s+ON%s+[%w_%.]+%s*[=<>!]+%s*[%w_%.]+%s+AND%s+[%w_%.]*$") then
    extra = {}
    local left_side = extract_left_side_column(before_cursor)
    if left_side then
      extra.left_side = left_side
    end
    ctx_type = Context.Type.COLUMN
    mode = "on"
    -- Check for qualified column reference in ON clause (e.g., d.█)
    if before_cursor:match("%.%s*$") or before_cursor:match("%.[%w_]*$") then
      local ref = Context._get_reference_before_dot(before_cursor)
      if ref then
        extra.table_ref = ref
        mode = "qualified"
      end
    end
    goto build_context
  end

  if chunk then
    local StatementParser = require('ssns.completion.statement_parser')

    -- Check if we're inside a subquery with its own clause positions
    local clause_source = chunk
    if cache_ctx and cache_ctx.subquery and cache_ctx.subquery.clause_positions then
      -- Create a pseudo-chunk with subquery's clause positions for clause detection
      clause_source = {
        clause_positions = cache_ctx.subquery.clause_positions
      }
    end

    local clause = StatementParser.get_clause_at_position(clause_source, line_num, col)

    if clause then
      -- Use clause position to determine context
      extra = {}
      if clause == "select" then
        ctx_type = Context.Type.COLUMN
        mode = "select"
      elseif clause == "from" then
        ctx_type = Context.Type.TABLE
        mode = "from"
        -- Parse qualified name from line (e.g., "FROM dbo.█" or "FROM TEST.dbo.█")
        -- Handle comma-separated tables: "FROM Table1, dbo.█" should extract "dbo."
        -- Look for the last segment that could be a qualified name
        local qualified_text = nil
        -- Try after last comma first (handles comma-separated tables)
        local after_comma = before_cursor:match(",[ \t]*([%w_%[%]%.]+)$")
        if after_comma then
          qualified_text = after_comma
        else
          -- No comma - try after FROM
          local after_from = before_cursor:match("[Ff][Rr][Oo][Mm]%s+([%w_%[%]%.]+)$")
          qualified_text = after_from
        end
        -- If no FROM on this line, check if we have a qualified pattern (multi-line case)
        if not qualified_text then
          -- Multi-line: before_cursor might be just "dbo." or "TEST.dbo."
          qualified_text = before_cursor:match("^%s*([%w_%[%]]+%.[%w_%[%]%.]*)$")
        end
        if qualified_text and qualified_text:match("%.") then
          local qualified = Context._parse_qualified_name(qualified_text)
          if qualified.database then
            extra.database = qualified.database
            extra.schema = qualified.schema
            extra.filter_database = qualified.database
            extra.filter_schema = qualified.schema
            extra.omit_schema = true
            mode = "from_cross_db_qualified"
          elseif qualified.schema then
            -- Check if this single identifier is a database name (cross-db schema completion)
            -- For "TEST.█", qualified.schema would be "TEST"
            -- We need to check if TEST is a known database on the server
            -- Pass potential_database so providers can validate it
            local potential_db = qualified.schema
            extra.potential_database = potential_db
            extra.schema = qualified.schema
            extra.filter_schema = qualified.schema
            extra.omit_schema = true
            mode = "from_qualified"
          end
        end
      elseif clause == "join" then
        ctx_type = Context.Type.TABLE
        mode = "join"
        -- Parse qualified name from line (e.g., "JOIN dbo.█" or "JOIN TEST.dbo.█")
        -- Look for the last segment that could be a qualified name
        local qualified_text = nil
        -- Try after JOIN keyword
        local after_join = before_cursor:match("[Jj][Oo][Ii][Nn]%s+([%w_%[%]%.]+)$")
        qualified_text = after_join
        -- If no JOIN on this line, check if we have a qualified pattern (multi-line case)
        if not qualified_text then
          -- Multi-line: before_cursor might be just "dbo." or "TEST.dbo."
          qualified_text = before_cursor:match("^%s*([%w_%[%]]+%.[%w_%[%]%.]*)$")
        end
        if qualified_text and qualified_text:match("%.") then
          local qualified = Context._parse_qualified_name(qualified_text)
          if qualified.database then
            extra.database = qualified.database
            extra.schema = qualified.schema
            extra.filter_database = qualified.database
            extra.filter_schema = qualified.schema
            extra.omit_schema = true
            mode = "join_cross_db_qualified"
          elseif qualified.schema then
            extra.schema = qualified.schema
            extra.filter_schema = qualified.schema
            extra.omit_schema = true
            mode = "join_qualified"
          end
        end
      elseif clause == "on" then
        ctx_type = Context.Type.COLUMN
        mode = "on"
        local left_side = extract_left_side_column(before_cursor)
        if left_side then
          extra.left_side = left_side
        end
        -- Check for qualified column reference in ON clause (e.g., d.█)
        if before_cursor:match("%.%s*$") or before_cursor:match("%.[%w_]*$") then
          local ref = Context._get_reference_before_dot(before_cursor)
          if ref then
            extra.table_ref = ref
            mode = "qualified"
          end
        end
      elseif clause == "where" then
        ctx_type = Context.Type.COLUMN
        mode = "where"
        local left_side = extract_left_side_column(before_cursor)
        if left_side then
          extra.left_side = left_side
        end
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
      elseif clause == "values" then
        ctx_type = Context.Type.COLUMN
        mode = "values"
      end

      -- Check for qualified column reference (alias.column, table.column)
      -- BUT: Don't override TABLE context clauses - those are qualified table references
      -- TABLE context clauses: from, join, into, update, delete, merge
      if (before_cursor:match("%.%s*$") or before_cursor:match("%.[%w_]*$")) and
         clause ~= "from" and clause ~= "join" and clause ~= "into" and
         clause ~= "update" and clause ~= "delete" and clause ~= "merge" then
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
      -- Clause detection returned nil - check if we're just past a FROM or JOIN clause
      -- This handles cases like "SELECT\n*\nFROM\ndbo.█" where the cursor is at col 5
      -- but FROM clause ends at col 4 (the position of "." in "dbo.")
      extra = {}
      local from_pos = chunk.clause_positions and chunk.clause_positions["from"]
      local join_pos = nil
      local where_pos = chunk.clause_positions and chunk.clause_positions["where"]
      local group_by_pos = chunk.clause_positions and chunk.clause_positions["group_by"]
      local having_pos = chunk.clause_positions and chunk.clause_positions["having"]
      local order_by_pos = chunk.clause_positions and chunk.clause_positions["order_by"]

      if chunk.clause_positions then
        -- Find most recent join clause
        for k, v in pairs(chunk.clause_positions) do
          if k:match("^join_%d+$") or k == "join" then
            if not join_pos or v.end_line > join_pos.end_line or
               (v.end_line == join_pos.end_line and v.end_col > join_pos.end_col) then
              join_pos = v
            end
          end
        end
      end

      -- Helper to check if cursor is past a clause start
      local function cursor_past_clause_start(clause_pos)
        if not clause_pos then return false end
        return line_num > clause_pos.start_line or
               (line_num == clause_pos.start_line and col > clause_pos.start_col)
      end

      -- Don't consider FROM/JOIN context if cursor is past WHERE/GROUP BY/HAVING/ORDER BY
      local past_where = cursor_past_clause_start(where_pos)
      local past_group_by = cursor_past_clause_start(group_by_pos)
      local past_having = cursor_past_clause_start(having_pos)
      local past_order_by = cursor_past_clause_start(order_by_pos)
      local in_later_clause = past_where or past_group_by or past_having or past_order_by

      -- Check if cursor is on the same line as FROM clause end or immediately after
      local in_from_context = from_pos and not in_later_clause and
        (line_num == from_pos.end_line or
         (line_num == from_pos.end_line + 1 and col <= 50)) -- Allow continuation on next line
      local in_join_context = join_pos and not in_later_clause and
        (line_num == join_pos.end_line or
         (line_num == join_pos.end_line + 1 and col <= 50))

      if in_from_context or in_join_context then
        -- We're continuing a FROM or JOIN clause - check for qualified name
        local qualified_text = before_cursor:match("^%s*([%w_%[%]]+%.[%w_%[%]%.]*)$")
        if qualified_text and qualified_text:match("%.") then
          local qualified = Context._parse_qualified_name(qualified_text)
          if qualified.database then
            extra.database = qualified.database
            extra.schema = qualified.schema
            extra.filter_database = qualified.database
            extra.filter_schema = qualified.schema
            extra.omit_schema = true
            ctx_type = Context.Type.TABLE
            mode = in_join_context and "join_cross_db_qualified" or "from_cross_db_qualified"
          elseif qualified.schema then
            extra.potential_database = qualified.schema
            extra.schema = qualified.schema
            extra.filter_schema = qualified.schema
            extra.omit_schema = true
            ctx_type = Context.Type.TABLE
            mode = in_join_context and "join_qualified" or "from_qualified"
          else
            ctx_type = Context.Type.TABLE
            mode = in_join_context and "join" or "from"
          end
        else
          ctx_type = Context.Type.TABLE
          mode = in_join_context and "join" or "from"
        end
      else
        -- Fallback to line-based detection
        ctx_type, mode, extra = Context._detect_type_from_line(before_cursor, chunk)
      end
    end
  else
    -- No chunk, use line-based detection
    ctx_type, mode, extra = Context._detect_type_from_line(before_cursor, chunk)
  end

  -- Label for goto from INSERT column list detection
  ::build_context::

  -- Build tables_in_scope array from cache_ctx.tables
  -- Format: {alias = "e", table = "dbo.EMPLOYEES", scope = "main"}
  -- or for CTEs: {name = "CTE_Name", is_cte = true, columns = {...}}
  -- or for subqueries: {name = "sub", is_subquery = true, columns = {...}}
  local tables_in_scope = {}
  local seen_ctes = {} -- Track which CTEs have been added to avoid duplicates
  local seen_subqueries = {} -- Track which subqueries have been added to avoid duplicates
  if cache_ctx and cache_ctx.tables then
    for _, table_ref in ipairs(cache_ctx.tables) do
      -- Preserve CTE entries with their columns
      if table_ref.is_cte then
        local cte_name = table_ref.name
        if not seen_ctes[cte_name:lower()] then
          seen_ctes[cte_name:lower()] = true
          -- Look up columns from the CTE definition if not present on table_ref
          local cte_columns = table_ref.columns
          if (not cte_columns or #cte_columns == 0) and cache_ctx.ctes then
            local cte_def = cache_ctx.ctes[cte_name] or cache_ctx.ctes[cte_name:lower()]
            if cte_def then
              cte_columns = cte_def.columns
            end
          end
          table.insert(tables_in_scope, {
            name = cte_name,
            is_cte = true,
            columns = cte_columns,
          })
        end
      elseif table_ref.is_subquery then
        -- Preserve subquery/derived table entries with their columns
        local sq_name = table_ref.name or table_ref.alias
        if sq_name and not seen_subqueries[sq_name:lower()] then
          seen_subqueries[sq_name:lower()] = true
          table.insert(tables_in_scope, {
            name = sq_name,
            alias = table_ref.alias,
            is_subquery = true,
            columns = table_ref.columns,
          })
        end
      else
        local table_name = table_ref.name
        -- Build qualified table name if schema is present
        if table_ref.schema then
          table_name = table_ref.schema .. "." .. table_ref.name
        end
        if table_ref.database then
          table_name = table_ref.database .. "." .. table_name
        end

        table.insert(tables_in_scope, {
          alias = table_ref.alias,
          table = table_name,
          scope = "main",  -- Could be "main" or "subquery" in the future
        })
      end
    end
  end

  -- Convert aliases from {alias_lower -> TableReference} to {alias_lower -> table_name_string}
  local aliases_map = {}
  if cache_ctx and cache_ctx.aliases then
    for alias_lower, table_ref in pairs(cache_ctx.aliases) do
      local table_name = table_ref.name
      -- Build qualified table name if schema is present
      if table_ref.schema then
        table_name = table_ref.schema .. "." .. table_ref.name
      end
      if table_ref.database then
        table_name = table_ref.database .. "." .. table_name
      end
      aliases_map[alias_lower] = table_name
    end
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
    aliases = aliases_map,  -- Converted format: alias_lower -> table_name_string
    ctes = cache_ctx and cache_ctx.ctes or {},
    temp_tables = cache_ctx and cache_ctx.temp_tables or {},
    subquery = cache_ctx and cache_ctx.subquery,
    tables_in_scope = tables_in_scope,  -- New field for Resolver

    -- Extra context from type detection
    table_ref = extra.table_ref,
    schema = extra.schema,
    database = extra.database,
    filter_schema = extra.filter_schema,
    filter_database = extra.filter_database,
    filter_table = extra.filter_table,
    potential_database = extra.potential_database,
    omit_schema = extra.omit_schema,
    omit_table = extra.omit_table,
    value_position = extra.value_position,
    left_side = extra.left_side,
    -- INSERT column list context
    insert_table = extra.insert_table,
    insert_schema = extra.insert_schema,
    table = extra.table,
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
