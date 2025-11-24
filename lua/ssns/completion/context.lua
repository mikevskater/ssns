---SQL context detection for intelligent completion
---Analyzes cursor position and SQL syntax to determine what kind of completion to provide
---Uses Tree-sitter for robust parsing with regex fallback
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

---Detect SQL context from cursor position using tree-sitter AST analysis
---@param bufnr number Buffer number
---@param line_num number Line number (1-indexed)
---@param col number Column number (1-indexed, byte offset)
---@return table context { type: ContextType, prefix: string, trigger?: string, table_ref?: string, alias?: string, schema?: string, database?: string }
function Context.detect(bufnr, line_num, col)
  local Debug = require('ssns.debug')

  Debug.log(string.format("[CONTEXT] detect() called: line_num=%d, col=%d", line_num, col))

  -- Tree-sitter is now REQUIRED
  local Treesitter = require('ssns.completion.metadata.treesitter')
  if not Treesitter.is_available() then
    vim.notify(
      "SSNS IntelliSense requires tree-sitter SQL parser.\n" ..
      "Install with: :TSInstall sql",
      vim.log.levels.ERROR
    )
    return {
      type = Context.Type.UNKNOWN,
      prefix = "",
    }
  end

  -- Use tree-sitter for all context detection
  local ts_result = Context.detect_with_treesitter(bufnr, line_num, col)

  if ts_result then
    Debug.log(string.format("[CONTEXT] Tree-sitter result: type=%s, mode=%s, schema=%s",
      tostring(ts_result.type), tostring(ts_result.mode), tostring(ts_result.schema or "nil")))
    return ts_result
  end

  -- Fallback to unknown context
  Debug.log("[CONTEXT] Tree-sitter returned nil, using UNKNOWN context")
  return {
    type = Context.Type.UNKNOWN,
    prefix = "",
  }
end

--- Detect completion context using tree-sitter AST analysis
---@param bufnr number Buffer number
---@param row number Cursor row (1-indexed)
---@param col number Cursor column (1-indexed)
---@return table? Context information (nil if tree-sitter unavailable or no context found)
function Context.detect_with_treesitter(bufnr, row, col)
  local Debug = require('ssns.debug')
  local Treesitter = require('ssns.completion.metadata.treesitter')

  Debug.log(string.format("[CONTEXT] detect_with_treesitter() called: bufnr=%d, row=%d, col=%d",
    bufnr, row, col))

  -- Get full buffer text
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")

  -- Parse SQL with tree-sitter
  local ok, parser = pcall(vim.treesitter.get_string_parser, text, "sql")
  if not ok then
    Debug.log("[CONTEXT] Failed to parse SQL with tree-sitter")
    return nil
  end

  local tree = parser:parse()[1]
  local root = tree:root()

  -- Get node at cursor position (0-indexed for tree-sitter)
  -- Clamp column to line length to handle cursor at/beyond end of line
  local line_text = lines[row] or ""
  local max_col = math.max(0, #line_text - 1) -- Last valid 0-indexed position
  local ts_row = row - 1
  local ts_col = math.min(col - 1, max_col) -- Clamp to valid range

  Debug.log(string.format("[CONTEXT] Tree-sitter position: row=%d, col=%d (clamped from %d)",
    ts_row, ts_col, col - 1))

  local cursor_node = root:named_descendant_for_range(ts_row, ts_col, ts_row, ts_col)

  if not cursor_node then
    Debug.log("[CONTEXT] No node found at cursor position")
    return nil
  end

  Debug.log(string.format("[CONTEXT] Node at cursor: type='%s'", cursor_node:type()))

  -- Check if we're in an ERROR node or child of ERROR node (incomplete SQL)
  local error_node = nil
  if cursor_node:type() == "ERROR" then
    error_node = cursor_node
    Debug.log("[CONTEXT] Cursor is on ERROR node")
  elseif cursor_node:parent() and cursor_node:parent():type() == "ERROR" then
    error_node = cursor_node:parent()
    Debug.log("[CONTEXT] Cursor is child of ERROR node")
  end

  if error_node then
    Debug.log("[CONTEXT] ERROR context detected, checking siblings for context")
    local sibling_result = Context._handle_error_from_sibling(error_node, lines, row, col)
    if sibling_result then
      Debug.log(string.format("[CONTEXT] Sibling recovery successful: type=%s, mode=%s",
        tostring(sibling_result.type), tostring(sibling_result.mode)))
      return sibling_result
    end
    Debug.log("[CONTEXT] Sibling recovery failed, continuing with tree walk")
  end

  -- Walk up the tree to find statement context
  local current = cursor_node
  local statement_context = nil

  while current do
    local node_type = current:type()
    Debug.log(string.format("[CONTEXT] Checking parent node: type='%s'", node_type))

    -- FROM clause context
    if node_type == "from_clause" or node_type == "from" then
      statement_context = Context._handle_from_context(current, lines, row, col)
      break

    -- JOIN clause context
    elseif node_type:match("join") then
      statement_context = Context._handle_join_context(current, lines, row, col)
      break

    -- WHERE clause context
    elseif node_type == "where_clause" or node_type == "where" then
      statement_context = Context._handle_where_context(current, lines, row, col)
      break

    -- SELECT clause context
    elseif node_type == "select" or node_type == "select_statement" or node_type == "select_clause" then
      statement_context = Context._handle_select_context(current, cursor_node, lines, row, col)
      break

    -- INSERT/UPDATE/DELETE contexts
    elseif node_type == "insert_statement" then
      statement_context = Context._handle_insert_context(current, lines, row, col)
      break
    elseif node_type == "update_statement" then
      statement_context = Context._handle_update_context(current, lines, row, col)
      break
    elseif node_type == "delete_statement" then
      statement_context = Context._handle_delete_context(current, lines, row, col)
      break
    end

    current = current:parent()
  end

  if statement_context then
    Debug.log(string.format("[CONTEXT] Statement context found: type=%s, mode=%s",
      tostring(statement_context.type), tostring(statement_context.mode)))
    return statement_context
  end

  Debug.log("[CONTEXT] No statement context found")
  return nil
end

---Handle FROM clause context
---@param node table Tree-sitter node
---@param lines table Buffer lines
---@param row number Cursor row (1-indexed)
---@param col number Cursor column (1-indexed)
---@return table context Context information
function Context._handle_from_context(node, lines, row, col)
  local Debug = require('ssns.debug')
  Debug.log("[CONTEXT] Handling FROM context")

  local current_line = lines[row] or ""
  local before_cursor = current_line:sub(1, col)
  local before_cursor_lower = before_cursor:lower()

  -- Check for schema qualifier (schema.)
  local schema = before_cursor_lower:match("(%w+)%.$")

  if schema then
    Debug.log(string.format("[CONTEXT] FROM with schema qualifier: '%s'", schema))
    return {
      type = Context.Type.TABLE,
      mode = "from_qualified",
      trigger = ".",
      prefix = before_cursor,
      schema = schema,
      filter_schema = schema,
      omit_schema = true,
    }
  else
    Debug.log("[CONTEXT] FROM without qualifier")
    return {
      type = Context.Type.TABLE,
      mode = "from",
      trigger = nil,
      prefix = before_cursor,
    }
  end
end

---Handle JOIN clause context
---@param node table Tree-sitter node
---@param lines table Buffer lines
---@param row number Cursor row (1-indexed)
---@param col number Cursor column (1-indexed)
---@return table context Context information
function Context._handle_join_context(node, lines, row, col)
  local Debug = require('ssns.debug')
  Debug.log("[CONTEXT] Handling JOIN context")

  local current_line = lines[row] or ""
  local before_cursor = current_line:sub(1, col)
  local before_cursor_lower = before_cursor:lower()

  local schema = before_cursor_lower:match("(%w+)%.$")

  if schema then
    Debug.log(string.format("[CONTEXT] JOIN with schema qualifier: '%s'", schema))
    return {
      type = Context.Type.TABLE,
      mode = "join_qualified",
      trigger = ".",
      prefix = before_cursor,
      schema = schema,
      filter_schema = schema,
      omit_schema = true,
    }
  else
    Debug.log("[CONTEXT] JOIN without qualifier")
    return {
      type = Context.Type.TABLE,
      mode = "join",
      trigger = nil,
      prefix = before_cursor,
    }
  end
end

---Handle WHERE clause context
---@param node table Tree-sitter node
---@param lines table Buffer lines
---@param row number Cursor row (1-indexed)
---@param col number Cursor column (1-indexed)
---@return table context Context information
function Context._handle_where_context(node, lines, row, col)
  local Debug = require('ssns.debug')
  Debug.log("[CONTEXT] Handling WHERE context")

  local current_line = lines[row] or ""
  local before_cursor = current_line:sub(1, col)

  -- WHERE context is always column completion
  return {
    type = Context.Type.COLUMN,
    mode = "where",
    trigger = nil,
    prefix = before_cursor,
  }
end

---Handle SELECT clause context
---@param select_node table Tree-sitter node (SELECT statement)
---@param cursor_node table Tree-sitter node at cursor
---@param lines table Buffer lines
---@param row number Cursor row (1-indexed)
---@param col number Cursor column (1-indexed)
---@return table context Context information
function Context._handle_select_context(select_node, cursor_node, lines, row, col)
  local Debug = require('ssns.debug')
  Debug.log("[CONTEXT] Handling SELECT context")

  local current_line = lines[row] or ""
  local before_cursor = current_line:sub(1, col)

  -- Check if we're after FROM (which means we're in FROM clause, not SELECT list)
  -- This handles cases where cursor is between SELECT and FROM
  local has_from = false
  for child in select_node:iter_children() do
    if child:type() == "from_clause" or child:type() == "from" then
      has_from = true
      local from_row = child:start()
      if from_row < row - 1 then
        -- FROM is before cursor, we might be in FROM context
        -- Let FROM handler take over
        return Context._handle_from_context(child, lines, row, col)
      end
    end
  end

  -- In SELECT list - column completion
  return {
    type = Context.Type.COLUMN,
    mode = "select",
    trigger = nil,
    prefix = before_cursor,
  }
end

---Handle INSERT context
---@param node table Tree-sitter node
---@param lines table Buffer lines
---@param row number Cursor row (1-indexed)
---@param col number Cursor column (1-indexed)
---@return table context Context information
function Context._handle_insert_context(node, lines, row, col)
  local current_line = lines[row] or ""
  local before_cursor = current_line:sub(1, col)
  local before_cursor_lower = before_cursor:lower()

  local schema = before_cursor_lower:match("into%s+(%w+)%.$")

  if schema then
    return {
      type = Context.Type.TABLE,
      mode = "insert_qualified",
      trigger = ".",
      prefix = before_cursor,
      schema = schema,
      filter_schema = schema,
      omit_schema = true,
    }
  else
    return {
      type = Context.Type.TABLE,
      mode = "insert",
      trigger = nil,
      prefix = before_cursor,
    }
  end
end

---Handle UPDATE context
---@param node table Tree-sitter node
---@param lines table Buffer lines
---@param row number Cursor row (1-indexed)
---@param col number Cursor column (1-indexed)
---@return table context Context information
function Context._handle_update_context(node, lines, row, col)
  local current_line = lines[row] or ""
  local before_cursor = current_line:sub(1, col)
  local before_cursor_lower = before_cursor:lower()

  local schema = before_cursor_lower:match("update%s+(%w+)%.$")

  if schema then
    return {
      type = Context.Type.TABLE,
      mode = "update_qualified",
      trigger = ".",
      prefix = before_cursor,
      schema = schema,
      filter_schema = schema,
      omit_schema = true,
    }
  else
    return {
      type = Context.Type.TABLE,
      mode = "update",
      trigger = nil,
      prefix = before_cursor,
    }
  end
end

---Handle DELETE context
---@param node table Tree-sitter node
---@param lines table Buffer lines
---@param row number Cursor row (1-indexed)
---@param col number Cursor column (1-indexed)
---@return table context Context information
function Context._handle_delete_context(node, lines, row, col)
  local current_line = lines[row] or ""
  local before_cursor = current_line:sub(1, col)
  local before_cursor_lower = before_cursor:lower()

  local schema = before_cursor_lower:match("from%s+(%w+)%.$")

  if schema then
    return {
      type = Context.Type.TABLE,
      mode = "delete_qualified",
      trigger = ".",
      prefix = before_cursor,
      schema = schema,
      filter_schema = schema,
      omit_schema = true,
    }
  else
    return {
      type = Context.Type.TABLE,
      mode = "delete",
      trigger = nil,
      prefix = before_cursor,
    }
  end
end

---Handle error recovery by checking previous sibling context
---@param error_node table Tree-sitter ERROR node
---@param lines table Buffer lines
---@param row number Cursor row (1-indexed)
---@param col number Cursor column (1-indexed)
---@return table? Context information (nil if no context found)
function Context._handle_error_from_sibling(error_node, lines, row, col)
  local Debug = require('ssns.debug')
  Debug.log("[CONTEXT] ERROR node - checking previous sibling for context")

  -- Check previous sibling (should be the statement we're continuing from)
  local prev_sibling = error_node:prev_sibling()
  if not prev_sibling then
    Debug.log("[CONTEXT] No previous sibling found")
    return nil
  end

  Debug.log(string.format("[CONTEXT] Previous sibling type: %s", prev_sibling:type()))

  -- If previous sibling is a statement, find the last meaningful clause
  if prev_sibling:type() == "statement" then
    -- Walk through children to find context nodes (from, where, select, etc.)
    local last_context_node = nil
    local last_context_type = nil

    for child in prev_sibling:iter_children() do
      local child_type = child:type()
      Debug.log(string.format("[CONTEXT] Statement child: %s", child_type))

      if child_type == "from" or child_type == "from_clause" then
        last_context_node = child
        last_context_type = "from"
      elseif child_type:match("join") then
        last_context_node = child
        last_context_type = "join"
      elseif child_type == "where" or child_type == "where_clause" then
        last_context_node = child
        last_context_type = "where"
      elseif child_type == "select" or child_type == "select_statement" or child_type == "select_clause" then
        last_context_node = child
        last_context_type = "select"
      end
    end

    -- Use the last context node found
    if last_context_node and last_context_type then
      Debug.log(string.format("[CONTEXT] Found context in prev sibling: %s", last_context_type))

      -- Call the appropriate handler
      if last_context_type == "from" then
        return Context._handle_from_context(last_context_node, lines, row, col)
      elseif last_context_type == "join" then
        return Context._handle_join_context(last_context_node, lines, row, col)
      elseif last_context_type == "where" then
        return Context._handle_where_context(last_context_node, lines, row, col)
      elseif last_context_type == "select" then
        -- For select, we need to pass cursor_node too, use error_node as cursor
        return Context._handle_select_context(last_context_node, error_node, lines, row, col)
      end
    end
  end

  Debug.log("[CONTEXT] No usable context found in previous sibling")
  return nil
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
---Enhanced with Tree-sitter support, falls back to regex
---@param query string The SQL query (can be multi-line)
---@param scope_node? table Optional tree-sitter node for scope-aware extraction
---@return table<string, string> aliases Map of alias -> table_name
function Context.parse_aliases(query, scope_node)
  -- TRY: Tree-sitter parsing first (more robust, handles comments/strings)
  local Treesitter = require('ssns.completion.metadata.treesitter')
  if Treesitter.is_available() then
    local refs

    -- Use scope-aware extraction if node provided
    if scope_node then
      refs = Treesitter.extract_table_references_in_scope(scope_node, query)
    else
      -- Use global extraction (old behavior)
      refs = Treesitter.extract_table_references(query)
    end

    if refs and #refs > 0 then
      -- Convert refs to alias map
      local aliases = {}
      for _, ref in ipairs(refs) do
        if ref.alias then
          -- Handle schema-qualified: dbo.Employees -> dbo.Employees
          local table_name = ref.table
          if ref.schema then
            table_name = ref.schema .. "." .. ref.table
          end
          aliases[ref.alias:lower()] = table_name
        end
      end
      return aliases
    end
  end

  -- FALLBACK: Use existing regex-based parsing
  -- (Kept for compatibility when tree-sitter unavailable or returns no results)
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

---Get the SQL query/statement containing the cursor position
---@param bufnr number Buffer number
---@param row number Cursor row (1-indexed)
---@param col number Cursor column (1-indexed)
---@return string? query_text The SQL query at cursor (nil if not found)
---@return number? start_line Start line of the query (1-indexed)
---@return number? end_line End line of the query (1-indexed)
function Context.get_current_query_at_cursor(bufnr, row, col)
  local Treesitter = require('ssns.completion.metadata.treesitter')

  -- Check if tree-sitter is available
  if not Treesitter.is_available() then
    -- Fallback: return entire buffer
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    return table.concat(lines, "\n"), 1, #lines
  end

  -- Get full buffer content
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local buffer_text = table.concat(lines, "\n")

  -- Parse SQL with tree-sitter
  local root = Treesitter.parse_sql(buffer_text)
  if not root then
    return table.concat(lines, "\n"), 1, #lines
  end

  -- Convert to 0-indexed for tree-sitter
  local ts_row = row - 1
  local ts_col = col - 1

  -- Walk up from cursor to find containing SELECT statement
  local node = root:descendant_for_range(ts_row, ts_col, ts_row, ts_col)
  if not node then
    return table.concat(lines, "\n"), 1, #lines
  end

  -- Traverse up to find select_statement node
  local current = node
  while current do
    local node_type = current:type()

    if node_type == "select_statement" or
       node_type == "insert_statement" or
       node_type == "update_statement" or
       node_type == "delete_statement" then
      -- Found the statement containing cursor
      local start_row, _, end_row, _ = current:range()
      start_row = start_row + 1  -- Convert to 1-indexed
      end_row = end_row + 1

      -- Extract query text from this statement only
      local query_lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)
      return table.concat(query_lines, "\n"), start_row, end_row
    end

    current = current:parent()
  end

  -- No statement found, return entire buffer
  return buffer_text, 1, #lines
end

---Resolve table alias to actual table name (SCOPE-AWARE VERSION)
---@param alias string The alias to resolve (e.g., "e" from "e.column")
---@param bufnr number Buffer number
---@param cursor_pos? table {row, col} Cursor position (1-indexed) for scope filtering
---@return string? table_name Resolved table name (e.g., "dbo.Employees") or nil
function Context.resolve_alias(alias, bufnr, cursor_pos)
  local Treesitter = require('ssns.completion.metadata.treesitter')

  -- NEW: Get only the query containing cursor
  local query, start_line, end_line
  local scope_node = nil

  if cursor_pos then
    query, start_line, end_line = Context.get_current_query_at_cursor(
      bufnr, cursor_pos[1], cursor_pos[2]
    )

    -- If tree-sitter is available, get the scope node for more accurate extraction
    if Treesitter.is_available() then
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local buffer_text = table.concat(lines, "\n")
      local root = Treesitter.parse_sql(buffer_text)

      if root then
        -- Convert to 0-indexed for tree-sitter
        local ts_row = cursor_pos[1] - 1
        local ts_col = cursor_pos[2] - 1

        -- Walk up from cursor to find containing SELECT/INSERT/UPDATE/DELETE statement
        local node = root:descendant_for_range(ts_row, ts_col, ts_row, ts_col)
        if node then
          local current = node
          while current do
            local node_type = current:type()

            if node_type == "select_statement" or
               node_type == "insert_statement" or
               node_type == "update_statement" or
               node_type == "delete_statement" then
              -- Found the statement scope
              scope_node = current
              break
            end

            current = current:parent()
          end
        end
      end
    end
  else
    -- Fallback: entire buffer (old behavior)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    query = table.concat(lines, "\n")
  end

  -- Parse aliases from ONLY this query (with optional scope node)
  local aliases = Context.parse_aliases(query, scope_node)

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
