---Statement-based context detection for SQL completion
---Uses StatementCache/StatementChunk exclusively (no tree-sitter)
---Enhanced with token-based qualified name detection for accuracy
local Debug = require('ssns.debug')
local StatementCache = require('ssns.completion.statement_cache')
local TokenContext = require('ssns.completion.token_context')

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
---Also handles partial column names: "e.First" -> "e"
---Also handles bracketed identifiers: "[e]." -> "e"
---@param before_cursor string Text before cursor
---@return string? reference The table/alias reference, or nil
function Context._get_reference_before_dot(before_cursor)
  -- First, strip any partial column name after the last dot
  -- For "e.First" we want to get "e." then strip the dot to get "e"
  -- For "e." we just strip the dot to get "e"
  -- For "dbo.Employees.First" we want "dbo.Employees"

  -- Check if there's text after a dot (partial column name)
  -- Handle both regular identifiers and bracketed ones: .First or .[First]
  local text_after_dot = before_cursor:match("%.(%[?[%w_]+%]?)$")
  if text_after_dot then
    -- Strip the partial column name to get "SELECT e."
    before_cursor = before_cursor:sub(1, -(#text_after_dot + 1))
  end

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
    -- Strip surrounding brackets from each part for alias matching
    -- [e] -> e, [dbo].[Employees] -> dbo.Employees
    ref = ref:gsub("%[([^%]]+)%]", "%1")
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

---Detect qualified name using token-based analysis
---This is more reliable than regex because tokens have accurate positions
---@param bufnr number Buffer number
---@param line number 1-indexed line
---@param col number 1-indexed column
---@return QualifiedName? qualified Parsed qualified name, or nil
---@return boolean is_after_dot Whether cursor is immediately after a dot
local function detect_qualified_from_tokens(bufnr, line, col)
  -- Get tokens for the buffer
  local tokens = TokenContext.get_buffer_tokens(bufnr)
  if not tokens or #tokens == 0 then
    return nil, false
  end

  -- Check if we're after a dot
  local is_after_dot, qualified = TokenContext.is_dot_triggered(tokens, line, col)

  Debug.log(string.format("[token_context] is_after_dot=%s, parts=%s, schema=%s, database=%s",
    tostring(is_after_dot),
    qualified and table.concat(qualified.parts, ".") or "nil",
    qualified and qualified.schema or "nil",
    qualified and qualified.database or "nil"))

  return qualified, is_after_dot
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
    -- Parse qualified name for cross-database support: UPDATE TEST.dbo.█
    local qualified_text = before_cursor:match("[Uu][Pp][Dd][Aa][Tt][Ee]%s+([%w_%[%]%.]+)$")
    if qualified_text and qualified_text:match("%.") then
      local qualified = Context._parse_qualified_name(qualified_text)
      if qualified.database then
        extra.database = qualified.database
        extra.schema = qualified.schema
        extra.filter_database = qualified.database
        extra.filter_schema = qualified.schema
        return Context.Type.TABLE, "update", extra
      elseif qualified.schema then
        extra.schema = qualified.schema
        extra.filter_schema = qualified.schema
      end
    end
    return Context.Type.TABLE, "update", extra
  end

  if upper_trimmed:match("DELETE%s+FROM%s+$") or upper:match("DELETE%s+FROM%s+[%w_#@%.%[%]]*$") then
    return Context.Type.TABLE, "delete", extra
  end

  -- DELETE without FROM is valid T-SQL: DELETE table or DELETE dbo.table
  if upper_trimmed:match("DELETE%s+$") or upper:match("DELETE%s+[%w_#@%.%[%]]*$") then
    return Context.Type.TABLE, "delete", extra
  end

  -- TRUNCATE TABLE: TRUNCATE TABLE table_name
  if upper_trimmed:match("TRUNCATE%s+TABLE%s+$") or upper:match("TRUNCATE%s+TABLE%s+[%w_#@%.%[%]]*$") then
    return Context.Type.TABLE, "truncate", extra
  end

  -- ALTER TABLE: ALTER TABLE table_name
  if upper_trimmed:match("ALTER%s+TABLE%s+$") or upper:match("ALTER%s+TABLE%s+[%w_#@%.%[%]]*$") then
    return Context.Type.TABLE, "alter", extra
  end

  -- MERGE INTO target_table: MERGE INTO table AS target
  if upper_trimmed:match("MERGE%s+INTO%s+$") or upper:match("MERGE%s+INTO%s+[%w_#@%.%[%]]*$") then
    return Context.Type.TABLE, "merge", extra
  end

  -- MERGE USING source_table: MERGE ... USING table AS source
  if upper_trimmed:match("USING%s+$") or upper:match("USING%s+[%w_#@%.%[%]]*$") then
    -- Parse qualified name for cross-database support: USING TEST.dbo.█
    local after_using = trimmed:match("USING%s+(.*)$")
    if after_using then
      local qualified = Context._parse_qualified_name(after_using)
      if qualified.database then
        extra.database = qualified.database
        extra.schema = qualified.schema
        extra.filter_database = qualified.database
        extra.filter_schema = qualified.schema
        extra.omit_schema = true
        return Context.Type.TABLE, "merge_cross_db_qualified", extra
      elseif qualified.schema then
        -- Could be "schema." or "database." - set potential_database for provider to check
        extra.potential_database = qualified.schema
        extra.schema = qualified.schema
        extra.filter_schema = qualified.schema
        extra.omit_schema = true
        return Context.Type.TABLE, "merge_qualified", extra
      end
    end
    return Context.Type.TABLE, "merge", extra
  end

  -- MERGE INSERT column list: WHEN NOT MATCHED THEN INSERT (█) or INSERT (col1, █)
  -- This must come BEFORE regular INSERT INTO check to detect MERGE context
  local merge_insert_match = before_cursor:upper():match("WHEN%s+NOT%s+MATCHED[^;]*THEN%s+INSERT%s*%(")
  if merge_insert_match then
    -- For MERGE INSERT, the target table is from MERGE INTO earlier
    -- We need to get it from the parsed chunk
    extra.is_merge_insert = true
    return Context.Type.COLUMN, "merge_insert_columns", extra
  end

  -- OUTPUT clause with inserted/deleted pseudo-tables (MUST check BEFORE qualified column)
  -- Patterns: "OUTPUT inserted.█" or "OUTPUT deleted.█"
  local upper_before_out = before_cursor:upper()
  local output_inserted_early = upper_before_out:match("OUTPUT[^;]*INSERTED%.$")
  local output_deleted_early = upper_before_out:match("OUTPUT[^;]*DELETED%.$")
  if output_inserted_early then
    extra.is_output_clause = true
    extra.output_pseudo_table = "inserted"
    extra.table_ref = "inserted"
    return Context.Type.COLUMN, "output", extra
  elseif output_deleted_early then
    extra.is_output_clause = true
    extra.output_pseudo_table = "deleted"
    extra.table_ref = "deleted"
    return Context.Type.COLUMN, "output", extra
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
    -- Parse qualified name for cross-database support: INSERT INTO TEST.dbo.█
    local qualified_text = before_cursor:match("[Ii][Nn][Ss][Ee][Rr][Tt]%s+[Ii][Nn][Tt][Oo]%s+([%w_%[%]%.]+)$")
    if qualified_text and qualified_text:match("%.") then
      local qualified = Context._parse_qualified_name(qualified_text)
      if qualified.database then
        extra.database = qualified.database
        extra.schema = qualified.schema
        extra.filter_database = qualified.database
        extra.filter_schema = qualified.schema
        return Context.Type.TABLE, "insert", extra
      elseif qualified.schema then
        extra.schema = qualified.schema
        extra.filter_schema = qualified.schema
      end
    end
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
  -- Check for subquery SELECT context: (SELECT ... with no FROM after it
  -- This handles: WHERE col IN (SELECT █FROM table)
  -- The outer query has FROM but the subquery's SELECT should get column completion
  if before_upper:match("%(%s*SELECT%s+$") or before_upper:match("%(%s*SELECT%s+[^%)]*$") then
    -- We're inside a subquery SELECT - check if there's a FROM after the subquery's SELECT
    local subquery_start = before_upper:match(".*%(%s*(SELECT.*)$")
    if subquery_start and not subquery_start:match("FROM") then
      return Context.Type.COLUMN, "select", extra
    end
  end
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

  -- OUTPUT clause without qualification - suggest both inserted and deleted
  -- (OUTPUT inserted./deleted. patterns are handled earlier, before the qualified column check)
  if upper_trimmed:match("OUTPUT%s+$") or upper:match("OUTPUT%s+[%w_%.]*$") then
    if chunk and (chunk.statement_type == "INSERT" or chunk.statement_type == "UPDATE" or
                  chunk.statement_type == "DELETE" or chunk.statement_type == "MERGE") then
      extra.is_output_clause = true
      return Context.Type.COLUMN, "output", extra
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

  -- Get tokens for buffer (used for token-based detection throughout)
  local tokens = TokenContext.get_buffer_tokens(bufnr)

  -- Get StatementCache context
  local cache_ctx = StatementCache.get_context_at_position(bufnr, line_num, col)

  -- Extract prefix and trigger using token-based detection
  local prefix, trigger = TokenContext.extract_prefix_and_trigger(tokens, line_num, col)

  -- NOTE: We now use token-based qualified name detection via detect_qualified_from_tokens()
  -- which properly handles cursor position relative to the trigger character (dot)
  -- The old before_cursor_with_trigger approach is no longer needed for FROM/JOIN clauses

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
    -- Use token-based left-side column extraction
    local left_side = TokenContext.extract_left_side_column(tokens, line_num, col)
    if left_side then
      extra.left_side = left_side
    end
    ctx_type = Context.Type.COLUMN
    mode = "on"
    -- Check for qualified column reference in ON clause (e.g., d.█) using token-based detection
    local is_after_dot, _ = TokenContext.is_dot_triggered(tokens, line_num, col)
    if is_after_dot then
      local ref = TokenContext.get_reference_before_dot(tokens, line_num, col)
      if ref then
        extra.table_ref = ref
        mode = "qualified"
      end
    end
    goto build_context
  end

  -- OUTPUT INTO table detection (MUST be BEFORE OUTPUT column detection)
  -- Pattern: "OUTPUT ... INTO █" - needs TABLE completion
  do
    local upper_for_output = before_cursor:upper()
    if upper_for_output:match("OUTPUT[^;]*INTO%s+$") or upper_for_output:match("OUTPUT[^;]*INTO%s+[%w_#@]*$") then
      extra = {}
      extra.is_output_into = true
      ctx_type = Context.Type.TABLE
      mode = "from"
      goto build_context
    end
  end

  -- EXEC/EXECUTE detection (MUST be BEFORE clause-based routing)
  -- Patterns: "EXEC █" or "INSERT INTO table EXEC █" - needs PROCEDURE completion
  do
    local upper_for_exec = before_cursor:upper()
    if upper_for_exec:match("EXEC%s+$") or upper_for_exec:match("EXECUTE%s+$") or
       upper_for_exec:match("EXEC%s+[%w_%.]*$") or upper_for_exec:match("EXECUTE%s+[%w_%.]*$") then
      extra = {}
      ctx_type = Context.Type.PROCEDURE
      mode = "exec"
      goto build_context
    end
  end

  -- OUTPUT clause detection (MUST be BEFORE clause-based routing since OUTPUT isn't tracked in clause_positions)
  -- Pattern: "OUTPUT inserted.█" or "OUTPUT deleted.█"
  -- Use do...end block to avoid goto scope issues with local variables
  do
    local upper_for_output = before_cursor:upper()
    local output_inserted_ctx = upper_for_output:match("OUTPUT[^;]*INSERTED%.$")
    local output_deleted_ctx = upper_for_output:match("OUTPUT[^;]*DELETED%.$")
    if output_inserted_ctx or output_deleted_ctx then
      extra = {}
      extra.is_output_clause = true
      extra.output_pseudo_table = output_inserted_ctx and "inserted" or "deleted"
      extra.table_ref = extra.output_pseudo_table
      ctx_type = Context.Type.COLUMN
      mode = "output"
      goto build_context
    end
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
    Debug.log(string.format("[statement_context] get_clause_at_position returned: %s", tostring(clause)))

    if clause then
      -- Use clause position to determine context
      extra = {}
      if clause == "select" then
        ctx_type = Context.Type.COLUMN
        mode = "select"
      elseif clause == "from" then
        ctx_type = Context.Type.TABLE
        mode = "from"
        -- Use token-based detection for reliable qualified name parsing
        -- This properly handles the cursor position relative to the dot
        local token_qualified, is_after_dot = detect_qualified_from_tokens(bufnr, line_num, col)

        -- Check if we're in a JOIN context (for proper mode naming)
        local is_join_context = before_cursor:upper():match("JOIN%s*$") ~= nil or
                                before_cursor:upper():match("JOIN%s+[%w_%[%]%.]+$") ~= nil
        if is_join_context then
          mode = "join"
        end

        if is_after_dot and token_qualified then
          Debug.log(string.format("[statement_context] Token-based qualified: has_trailing_dot=%s, parts=%s, schema=%s, database=%s",
            tostring(token_qualified.has_trailing_dot),
            table.concat(token_qualified.parts, "."),
            tostring(token_qualified.schema),
            tostring(token_qualified.database)))

          if token_qualified.database then
            -- db.schema.| pattern (cross-database qualified)
            extra.database = token_qualified.database
            extra.schema = token_qualified.schema
            extra.filter_database = token_qualified.database
            extra.filter_schema = token_qualified.schema
            extra.omit_schema = true
            mode = is_join_context and "join_cross_db_qualified" or "from_cross_db_qualified"
          elseif token_qualified.schema then
            -- schema.| pattern (schema qualified)
            -- Could also be a database name - pass potential_database for provider to validate
            extra.potential_database = token_qualified.schema
            extra.schema = token_qualified.schema
            extra.filter_schema = token_qualified.schema
            extra.omit_schema = true
            mode = is_join_context and "join_qualified" or "from_qualified"
            Debug.log(string.format("[statement_context] Set filter_schema=%s, mode=%s", extra.filter_schema, mode))
          end
        end
      elseif clause == "join" then
        ctx_type = Context.Type.TABLE
        mode = "join"
        -- Use token-based detection for reliable qualified name parsing
        local token_qualified, is_after_dot = detect_qualified_from_tokens(bufnr, line_num, col)

        if is_after_dot and token_qualified then
          Debug.log(string.format("[statement_context] JOIN Token-based qualified: has_trailing_dot=%s, parts=%s, schema=%s, database=%s",
            tostring(token_qualified.has_trailing_dot),
            table.concat(token_qualified.parts, "."),
            tostring(token_qualified.schema),
            tostring(token_qualified.database)))

          if token_qualified.database then
            extra.database = token_qualified.database
            extra.schema = token_qualified.schema
            extra.filter_database = token_qualified.database
            extra.filter_schema = token_qualified.schema
            extra.omit_schema = true
            mode = "join_cross_db_qualified"
          elseif token_qualified.schema then
            -- Could also be a database name - pass potential_database for provider to validate
            extra.potential_database = token_qualified.schema
            extra.schema = token_qualified.schema
            extra.filter_schema = token_qualified.schema
            extra.omit_schema = true
            mode = "join_qualified"
          end
        end
      elseif clause == "on" then
        ctx_type = Context.Type.COLUMN
        mode = "on"
        -- Use token-based left-side column extraction
        local left_side_on = TokenContext.extract_left_side_column(tokens, line_num, col)
        if left_side_on then
          extra.left_side = left_side_on
        end
        -- Check for qualified column reference in ON clause (e.g., d.█) using token-based detection
        local is_after_dot_on, _ = TokenContext.is_dot_triggered(tokens, line_num, col)
        if is_after_dot_on then
          local ref = TokenContext.get_reference_before_dot(tokens, line_num, col)
          if ref then
            extra.table_ref = ref
            mode = "qualified"
          end
        end
      elseif clause == "where" then
        ctx_type = Context.Type.COLUMN
        mode = "where"
        -- Use token-based left-side column extraction
        local left_side_where = TokenContext.extract_left_side_column(tokens, line_num, col)
        if left_side_where then
          extra.left_side = left_side_where
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
        -- Parse qualified name for cross-database support: INSERT INTO TEST.dbo.█
        local qualified_text = nil
        -- Try after INSERT INTO keyword
        local after_into = before_cursor:match("[Ii][Nn][Ss][Ee][Rr][Tt]%s+[Ii][Nn][Tt][Oo]%s+([%w_%[%]%.]+)$")
        qualified_text = after_into
        -- If no INSERT INTO on this line, check if we have a qualified pattern (multi-line case)
        if not qualified_text then
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
            mode = "into_cross_db_qualified"
          elseif qualified.schema then
            extra.schema = qualified.schema
            extra.filter_schema = qualified.schema
            extra.omit_schema = true
            mode = "into_qualified"
          end
        end
      elseif clause == "insert_columns" then
        ctx_type = Context.Type.COLUMN
        mode = "insert_columns"
      elseif clause == "values" then
        ctx_type = Context.Type.COLUMN
        mode = "values"
      end

      -- Check for qualified column reference (alias.column, table.column) using token-based detection
      -- BUT: Don't override TABLE context clauses - those are qualified table references
      -- TABLE context clauses: from, join, into, update, delete, merge
      local is_after_dot_qual, _ = TokenContext.is_dot_triggered(tokens, line_num, col)
      if is_after_dot_qual and
         clause ~= "from" and clause ~= "join" and clause ~= "into" and
         clause ~= "update" and clause ~= "delete" and clause ~= "merge" then
        local ref = TokenContext.get_reference_before_dot(tokens, line_num, col)
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
        local qualified_text = nil
        -- Try multiple patterns to find qualified name
        if in_join_context then
          -- Try after JOIN keyword (single-line case: "... JOIN TEST.dbo.")
          qualified_text = before_cursor:match("[Jj][Oo][Ii][Nn]%s+([%w_%[%]%.]+)$")
        end
        if not qualified_text and in_from_context then
          -- Try after FROM keyword (single-line case: "... FROM TEST.dbo.")
          qualified_text = before_cursor:match("[Ff][Rr][Oo][Mm]%s+([%w_%[%]%.]+)$")
          -- Also try after comma for second table (single-line case: "FROM Table1, TEST.dbo.")
          if not qualified_text then
            qualified_text = before_cursor:match(",%s*([%w_%[%]%.]+)$")
          end
        end
        -- Fallback: Try multi-line case where line starts with qualified name
        if not qualified_text then
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
        -- Fallback: Try token-based detection first
        -- Check special cases (VALUES, INSERT columns, MERGE INSERT, subquery SELECT) first
        ctx_type, mode, extra = TokenContext.detect_values_context_from_tokens(tokens, line_num, col)
        if not ctx_type then
          ctx_type, mode, extra = TokenContext.detect_insert_columns_from_tokens(tokens, line_num, col)
        end
        if not ctx_type then
          ctx_type, mode, extra = TokenContext.detect_merge_insert_from_tokens(tokens, line_num, col)
        end
        -- Then try general context detection (TABLE -> COLUMN -> OTHER)
        if not ctx_type then
          ctx_type, mode, extra = TokenContext.detect_table_context_from_tokens(tokens, line_num, col)
        end
        if not ctx_type then
          ctx_type, mode, extra = TokenContext.detect_column_context_from_tokens(tokens, line_num, col)
        end
        if not ctx_type then
          ctx_type, mode, extra = TokenContext.detect_other_context_from_tokens(tokens, line_num, col)
        end
        if not ctx_type then
          -- Final fallback to regex-based detection for any edge cases not yet converted
          ctx_type, mode, extra = Context._detect_type_from_line(before_cursor, chunk)
        end
      end
    end
  else
    -- No chunk: Try token-based detection first
    -- Check special cases (VALUES, INSERT columns, MERGE INSERT, subquery SELECT) first
    ctx_type, mode, extra = TokenContext.detect_values_context_from_tokens(tokens, line_num, col)
    if not ctx_type then
      ctx_type, mode, extra = TokenContext.detect_insert_columns_from_tokens(tokens, line_num, col)
    end
    if not ctx_type then
      ctx_type, mode, extra = TokenContext.detect_merge_insert_from_tokens(tokens, line_num, col)
    end
    -- Then try general context detection (TABLE -> COLUMN -> OTHER)
    if not ctx_type then
      ctx_type, mode, extra = TokenContext.detect_table_context_from_tokens(tokens, line_num, col)
    end
    if not ctx_type then
      ctx_type, mode, extra = TokenContext.detect_column_context_from_tokens(tokens, line_num, col)
    end
    if not ctx_type then
      ctx_type, mode, extra = TokenContext.detect_other_context_from_tokens(tokens, line_num, col)
    end
    if not ctx_type then
      -- Final fallback to regex-based detection for any edge cases not yet converted
      ctx_type, mode, extra = Context._detect_type_from_line(before_cursor, chunk)
    end
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
  local seen_temp_tables = {} -- Track which temp tables have been added to avoid duplicates
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
      elseif table_ref.is_temp_table then
        -- Preserve temp table entries with their columns
        local temp_name = table_ref.name
        if temp_name and not seen_temp_tables[temp_name:lower()] then
          seen_temp_tables[temp_name:lower()] = true
          -- Look up columns from temp_tables dict if not present on table_ref
          local temp_columns = table_ref.columns
          if (not temp_columns or #temp_columns == 0) and cache_ctx.temp_tables then
            local temp_def = cache_ctx.temp_tables[temp_name] or cache_ctx.temp_tables[temp_name:lower()]
            if temp_def then
              temp_columns = temp_def.columns
            end
          end
          table.insert(tables_in_scope, {
            name = temp_name,
            alias = table_ref.alias,
            is_temp_table = true,
            is_global = table_ref.is_global,
            columns = temp_columns,
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
      elseif table_ref.is_tvf then
        -- Preserve table-valued function (TVF) entries
        -- Columns will be looked up from database metadata when needed
        local tvf_name = table_ref.alias or table_ref.name
        if tvf_name then
          table.insert(tables_in_scope, {
            name = table_ref.name,
            alias = table_ref.alias,
            schema = table_ref.schema,
            is_tvf = true,
            function_name = table_ref.function_name or table_ref.name,
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

  -- Check if in comment or string using token-based detection
  -- This is more reliable than regex-based line parsing, especially for multi-line comments
  local tokens = TokenContext.get_buffer_tokens(bufnr)
  if TokenContext.is_in_string_or_comment(tokens, line_num, col) then
    -- Determine if it's a comment or string for the mode field
    local token_at = TokenContext.get_token_at_position(tokens, line_num, col)
    local mode = "string_or_comment"
    if token_at then
      if token_at.type == "comment" or token_at.type == "line_comment" then
        mode = "comment"
        Debug.log("[statement_context] Inside comment (token-based), skipping completion")
      elseif token_at.type == "string" then
        mode = "string"
        Debug.log("[statement_context] Inside string (token-based), skipping completion")
      end
    end
    return {
      type = Context.Type.UNKNOWN,
      mode = mode,
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
