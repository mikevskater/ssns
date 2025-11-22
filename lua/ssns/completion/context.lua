---SQL context detection for intelligent completion
---Analyzes cursor position and SQL syntax to determine what kind of completion to provide
---@class CompletionContext
local Context = {}

---SQL context type enumeration
---@enum ContextType
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

---Detect SQL context from cursor position
---@param bufnr number Buffer number
---@param line_num number Line number (1-indexed)
---@param col number Column number (1-indexed, byte offset)
---@return table context { type: ContextType, prefix: string, trigger?: string, table_ref?: string, alias?: string, schema?: string, database?: string }
function Context.detect(bufnr, line_num, col)
  -- CRITICAL: Fetch actual line from buffer (see INTELLISENSE_IMPLEMENTATION_GUIDE.md)
  -- The ctx.line from blink.cmp may not include the trigger character!
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
  if not lines or #lines == 0 then
    return { type = Context.Type.UNKNOWN, prefix = "" }
  end

  local line = lines[1]
  if not line then
    return { type = Context.Type.UNKNOWN, prefix = "" }
  end

  -- Get text before cursor
  local before_cursor = line:sub(1, col)
  local before_cursor_lower = before_cursor:lower()

  -- Detect trigger character at cursor
  local trigger = nil
  if before_cursor:match("%.$") then
    trigger = "."
  elseif before_cursor:match("%[$") then
    trigger = "["
  elseif before_cursor:match("%s$") then
    trigger = " "
  end

  -- Priority order (most specific first)

  -- 1. Qualified column reference: table.column| or alias.column|
  --    Pattern: word followed by dot
  if before_cursor:match("(%w+)%.$") then
    local ref = before_cursor:match("(%w+)%.$")
    return {
      type = Context.Type.COLUMN,
      prefix = before_cursor,
      trigger = ".",
      table_ref = ref,
      mode = "qualified",
    }
  end

  -- 2. Bracketed identifier: [schema].[table].| or [database].|
  --    Pattern: [word].[word].| or [word].|
  if before_cursor:match("%[([^%]]+)%]%.%[([^%]]+)%]%.$") then
    local part1, part2 = before_cursor:match("%[([^%]]+)%]%.%[([^%]]+)%]%.$")
    -- Could be [schema].[table]. or [database].[schema].
    -- Assume schema.table for now
    return {
      type = Context.Type.COLUMN,
      prefix = before_cursor,
      trigger = ".",
      schema = part1,
      table_ref = part2,
      mode = "qualified_bracket",
    }
  end

  if before_cursor:match("%[([^%]]+)%]%.$") then
    local part1 = before_cursor:match("%[([^%]]+)%]%.$")
    -- Could be [schema]. or [database].
    -- Need more context - check if followed by another identifier
    return {
      type = Context.Type.SCHEMA,
      prefix = before_cursor,
      trigger = ".",
      database = part1,
      mode = "qualified_bracket",
    }
  end

  -- 3. USE statement: USE |
  if before_cursor_lower:match("use%s+$") then
    return {
      type = Context.Type.DATABASE,
      prefix = before_cursor,
      trigger = " ",
      mode = "use",
    }
  end

  -- 4. FROM clause: FROM | or FROM schema.|
  if before_cursor_lower:match("from%s+$") then
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = " ",
      mode = "from",
    }
  end

  if before_cursor_lower:match("from%s+(%w+)%.$") then
    local schema = before_cursor_lower:match("from%s+(%w+)%.$")
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = ".",
      schema = schema,
      mode = "from_qualified",
    }
  end

  -- 5. JOIN clause: JOIN | or INNER JOIN | etc.
  if before_cursor_lower:match("join%s+$") then
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = " ",
      mode = "join",
    }
  end

  if before_cursor_lower:match("join%s+(%w+)%.$") then
    local schema = before_cursor_lower:match("join%s+(%w+)%.$")
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = ".",
      schema = schema,
      mode = "join_qualified",
    }
  end

  -- 6. INSERT INTO: INSERT INTO |
  if before_cursor_lower:match("insert%s+into%s+$") then
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = " ",
      mode = "insert",
    }
  end

  -- 7. UPDATE: UPDATE |
  if before_cursor_lower:match("update%s+$") then
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = " ",
      mode = "update",
    }
  end

  -- 8. DELETE FROM: DELETE FROM |
  if before_cursor_lower:match("delete%s+from%s+$") then
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = " ",
      mode = "delete",
    }
  end

  -- 9. SELECT clause: SELECT | (column completion)
  if before_cursor_lower:match("select%s+$") then
    return {
      type = Context.Type.COLUMN,
      prefix = before_cursor,
      trigger = " ",
      mode = "select",
    }
  end

  -- 10. WHERE clause: WHERE | (column completion)
  if before_cursor_lower:match("where%s+$") then
    return {
      type = Context.Type.COLUMN,
      prefix = before_cursor,
      trigger = " ",
      mode = "where",
    }
  end

  -- 11. ORDER BY clause: ORDER BY |
  if before_cursor_lower:match("order%s+by%s+$") then
    return {
      type = Context.Type.COLUMN,
      prefix = before_cursor,
      trigger = " ",
      mode = "order_by",
    }
  end

  -- 12. GROUP BY clause: GROUP BY |
  if before_cursor_lower:match("group%s+by%s+$") then
    return {
      type = Context.Type.COLUMN,
      prefix = before_cursor,
      trigger = " ",
      mode = "group_by",
    }
  end

  -- 13. EXEC/EXECUTE: EXEC | (procedure completion)
  if before_cursor_lower:match("exec%w*%s+$") then
    return {
      type = Context.Type.PROCEDURE,
      prefix = before_cursor,
      trigger = " ",
      mode = "exec",
    }
  end

  -- 14. After procedure name: EXEC proc | (parameter completion)
  local proc_name = before_cursor_lower:match("exec%w*%s+(%w+)%s+$")
  if proc_name then
    return {
      type = Context.Type.PARAMETER,
      prefix = before_cursor,
      trigger = " ",
      procedure = proc_name,
      mode = "exec_params",
    }
  end

  -- 15. Default: keyword completion
  return {
    type = Context.Type.KEYWORD,
    prefix = before_cursor,
    mode = "default",
  }
end

---Get statement type from line (SELECT, INSERT, UPDATE, DELETE, EXEC, etc.)
---@param line string The SQL line
---@return string? statement_type The detected statement type (uppercase)
function Context.get_statement_type(line)
  local line_lower = line:lower()

  -- Check common SQL statements
  if line_lower:match("^%s*select%s") then
    return "SELECT"
  elseif line_lower:match("^%s*insert%s") then
    return "INSERT"
  elseif line_lower:match("^%s*update%s") then
    return "UPDATE"
  elseif line_lower:match("^%s*delete%s") then
    return "DELETE"
  elseif line_lower:match("^%s*exec") then
    return "EXEC"
  elseif line_lower:match("^%s*execute%s") then
    return "EXECUTE"
  elseif line_lower:match("^%s*create%s") then
    return "CREATE"
  elseif line_lower:match("^%s*alter%s") then
    return "ALTER"
  elseif line_lower:match("^%s*drop%s") then
    return "DROP"
  elseif line_lower:match("^%s*use%s") then
    return "USE"
  end

  return nil
end

---Check if cursor is after a specific keyword
---@param line string The SQL line
---@param col number Column position (1-indexed)
---@param keyword string The keyword to check (case-insensitive)
---@return boolean is_after True if cursor is after the keyword
function Context.is_after_keyword(line, col, keyword)
  local before_cursor = line:sub(1, col):lower()
  local pattern = keyword:lower() .. "%s+"

  return before_cursor:match(pattern) ~= nil
end

---Extract table reference before dot (e.g., "employees." -> "employees")
---@param line string The SQL line
---@param col number Column position (1-indexed)
---@return string? table_ref The table/alias name before the dot
function Context.get_table_before_dot(line, col)
  local before_cursor = line:sub(1, col)

  -- Pattern: word followed by dot at end
  local ref = before_cursor:match("(%w+)%.$")
  if ref then
    return ref
  end

  -- Pattern: [bracketed] followed by dot
  ref = before_cursor:match("%[([^%]]+)%]%.$")
  if ref then
    return ref
  end

  return nil
end

---Parse query for table aliases (FROM/JOIN clauses)
---Returns a map of alias -> table_name
---@param query string The SQL query (can be multi-line)
---@return table<string, string> aliases Map of alias -> table_name
function Context.parse_aliases(query)
  local aliases = {}
  local query_lower = query:lower()

  -- Pattern 1: FROM table_name alias
  -- Example: FROM Employees e
  for table_name, alias in query_lower:gmatch("from%s+([%w%[%]%.]+)%s+(%w+)") do
    -- Clean up brackets if present
    table_name = table_name:gsub("%[", ""):gsub("%]", "")
    aliases[alias] = table_name
  end

  -- Pattern 2: JOIN table_name alias
  -- Example: INNER JOIN Departments d
  for table_name, alias in query_lower:gmatch("join%s+([%w%[%]%.]+)%s+(%w+)") do
    -- Clean up brackets if present
    table_name = table_name:gsub("%[", ""):gsub("%]", "")
    aliases[alias] = table_name
  end

  return aliases
end

---Resolve alias to table name using query context
---@param alias string The alias to resolve
---@param bufnr number Buffer number
---@return string? table_name The resolved table name (nil if not found)
function Context.resolve_alias(alias, bufnr)
  -- Get all lines from buffer to parse full query
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local query = table.concat(lines, "\n")

  -- Parse aliases from query
  local aliases = Context.parse_aliases(query)

  return aliases[alias:lower()]
end

---Check if line is inside a comment
---@param line string The SQL line
---@param col number Column position (1-indexed)
---@return boolean is_comment True if position is inside a comment
function Context.is_in_comment(line, col)
  local before_cursor = line:sub(1, col)

  -- Check for line comment (-- or #)
  if before_cursor:match("%-%-") or before_cursor:match("#") then
    return true
  end

  -- Check for block comment (/* ... */)
  -- Count opening and closing markers
  local opens = 0
  local closes = 0
  for _ in before_cursor:gmatch("/%*") do
    opens = opens + 1
  end
  for _ in before_cursor:gmatch("%*/") do
    closes = closes + 1
  end

  -- If more opens than closes, we're inside a block comment
  return opens > closes
end

---Check if line is inside a string literal
---@param line string The SQL line
---@param col number Column position (1-indexed)
---@return boolean is_string True if position is inside a string
function Context.is_in_string(line, col)
  local before_cursor = line:sub(1, col)

  -- Count single quotes (SQL strings)
  local single_quotes = 0
  for _ in before_cursor:gmatch("'") do
    single_quotes = single_quotes + 1
  end

  -- If odd number of quotes, we're inside a string
  return (single_quotes % 2) == 1
end

---Full context detection with all checks
---Entry point for blink.cmp source
---@param bufnr number Buffer number
---@param line_num number Line number (1-indexed)
---@param col number Column position (1-indexed)
---@return table context Full context information
function Context.detect_full(bufnr, line_num, col)
  -- Get line
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
  if not lines or #lines == 0 then
    return { type = Context.Type.UNKNOWN, prefix = "", should_complete = false }
  end

  local line = lines[1]

  -- Check if we're in a comment or string (disable completion)
  if Context.is_in_comment(line, col) or Context.is_in_string(line, col) then
    return {
      type = Context.Type.UNKNOWN,
      prefix = "",
      should_complete = false,
      reason = "inside_comment_or_string",
    }
  end

  -- Detect context
  local context = Context.detect(bufnr, line_num, col)
  context.should_complete = true
  context.line = line
  context.line_num = line_num
  context.col = col

  return context
end

return Context
