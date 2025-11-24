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

  local Debug = require('ssns.debug')
  Debug.log(string.format("[CONTEXT] detect() called: line_num=%d, col=%d, line='%s'",
    line_num, col, line or "nil"))

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
  -- CRITICAL: Check statement-specific qualified patterns BEFORE generic patterns
  -- to prevent "UPDATE dbo." from matching as generic "dbo." (column reference)

  -- 1. Bracketed identifier: [schema].[table].| or [database].|
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

  -- 2. USE statement: USE | or USE D| or USE Dev|
  if before_cursor_lower:match("use%s+%w*$") then
    return {
      type = Context.Type.DATABASE,
      prefix = before_cursor,
      trigger = " ",
      mode = "use",
    }
  end

  -- 3. DELETE FROM: DELETE FROM | or DELETE FROM E| or DELETE FROM Emp|
  -- DELETE FROM with qualification: DELETE FROM schema. or DELETE FROM db.schema.
  -- MUST be checked BEFORE generic FROM patterns!
  if before_cursor_lower:match("delete%s+from%s+(%w+)%.(%w+)%.$") then
    local database, schema = before_cursor_lower:match("delete%s+from%s+(%w+)%.(%w+)%.$")
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = ".",
      database = database,
      schema = schema,
      mode = "delete_qualified",
      omit_schema = true,
      filter_schema = schema,
    }
  end

  if before_cursor_lower:match("delete%s+from%s+(%w+)%.$") then
    local schema = before_cursor_lower:match("delete%s+from%s+(%w+)%.$")
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = ".",
      schema = schema,
      mode = "delete_qualified",
      omit_schema = true,
      filter_schema = schema,
    }
  end

  if before_cursor_lower:match("delete%s+from%s+%w*$") then
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = " ",
      mode = "delete",
    }
  end

  -- 4. INSERT INTO: INSERT INTO | or INSERT INTO E| or INSERT INTO Emp|
  -- INSERT INTO with qualification: INSERT INTO schema. or INSERT INTO db.schema.
  -- MUST be checked BEFORE generic qualified patterns!
  if before_cursor_lower:match("insert%s+into%s+(%w+)%.(%w+)%.$") then
    local database, schema = before_cursor_lower:match("insert%s+into%s+(%w+)%.(%w+)%.$")
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = ".",
      database = database,
      schema = schema,
      mode = "insert_qualified",
      omit_schema = true,
      filter_schema = schema,
    }
  end

  if before_cursor_lower:match("insert%s+into%s+(%w+)%.$") then
    local schema = before_cursor_lower:match("insert%s+into%s+(%w+)%.$")
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = ".",
      schema = schema,
      mode = "insert_qualified",
      omit_schema = true,
      filter_schema = schema,
    }
  end

  if before_cursor_lower:match("insert%s+into%s+%w*$") then
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = " ",
      mode = "insert",
    }
  end

  -- 5. UPDATE: UPDATE | or UPDATE E| or UPDATE Emp|
  -- UPDATE with qualification: UPDATE schema. or UPDATE db.schema.
  -- MUST be checked BEFORE generic qualified patterns!
  if before_cursor_lower:match("update%s+(%w+)%.(%w+)%.$") then
    local database, schema = before_cursor_lower:match("update%s+(%w+)%.(%w+)%.$")
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = ".",
      database = database,
      schema = schema,
      mode = "update_qualified",
      omit_schema = true,
      filter_schema = schema,
    }
  end

  if before_cursor_lower:match("update%s+(%w+)%.$") then
    local schema = before_cursor_lower:match("update%s+(%w+)%.$")
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = ".",
      schema = schema,
      mode = "update_qualified",
      omit_schema = true,
      filter_schema = schema,
    }
  end

  if before_cursor_lower:match("update%s+%w*$") then
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = " ",
      mode = "update",
    }
  end

  -- 6. FROM clause: FROM | or FROM E| or FROM Emp|
  if before_cursor_lower:match("from%s+%w*$") then
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = " ",
      mode = "from",
    }
  end

  -- FROM with qualification: FROM schema. or FROM db.schema.
  if before_cursor_lower:match("from%s+(%w+)%.(%w+)%.$") then
    -- Two-level: FROM database.schema.
    local database, schema = before_cursor_lower:match("from%s+(%w+)%.(%w+)%.$")
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = ".",
      database = database,
      schema = schema,
      mode = "from_qualified",
      omit_schema = true,  -- Schema already typed, don't include in insertText
      filter_schema = schema,  -- Only show objects from this schema
    }
  end

  if before_cursor_lower:match("from%s+(%w+)%.$") then
    -- One-level: FROM schema.
    local schema = before_cursor_lower:match("from%s+(%w+)%.$")
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = ".",
      schema = schema,
      mode = "from_qualified",
      omit_schema = true,  -- Schema already typed, don't include in insertText
      filter_schema = schema,  -- Only show objects from this schema
    }
  end

  -- 7. JOIN clause: JOIN | or JOIN D| or JOIN Dep|
  if before_cursor_lower:match("join%s+%w*$") then
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = " ",
      mode = "join",
    }
  end

  -- JOIN with qualification: JOIN schema. or JOIN db.schema.
  if before_cursor_lower:match("join%s+(%w+)%.(%w+)%.$") then
    -- Two-level: JOIN database.schema.
    local database, schema = before_cursor_lower:match("join%s+(%w+)%.(%w+)%.$")
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = ".",
      database = database,
      schema = schema,
      mode = "join_qualified",
      omit_schema = true,  -- Schema already typed, don't include in insertText
      filter_schema = schema,  -- Only show objects from this schema
    }
  end

  if before_cursor_lower:match("join%s+(%w+)%.$") then
    -- One-level: JOIN schema.
    local schema = before_cursor_lower:match("join%s+(%w+)%.$")
    return {
      type = Context.Type.TABLE,
      prefix = before_cursor,
      trigger = ".",
      schema = schema,
      mode = "join_qualified",
      omit_schema = true,  -- Schema already typed, don't include in insertText
      filter_schema = schema,  -- Only show objects from this schema
    }
  end

  -- 8. Qualified column reference: table.column| or alias.column|
  --    Pattern: word followed by dot (AFTER statement-specific patterns)
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

  -- 9. Qualified table/column reference with partial word: schema.Tab| or table.col|
  --    Pattern: word.word (no trailing dot)
  --    This handles cases like "FROM Production.Prod" where user is typing table name
  --    AFTER checking for qualified patterns with dots
  if before_cursor:match("(%w+)%.(%w+)$") then
    -- This could be schema.table or table.column depending on context
    -- Need to check parent statement type
    local part1, part2 = before_cursor:match("(%w+)%.(%w+)$")

    -- Check if we're in a table context (FROM, JOIN, INSERT, UPDATE, DELETE)
    if before_cursor_lower:match("from%s+%w+%.%w+$") or
       before_cursor_lower:match("join%s+%w+%.%w+$") or
       before_cursor_lower:match("insert%s+into%s+%w+%.%w+$") or
       before_cursor_lower:match("update%s+%w+%.%w+$") or
       before_cursor_lower:match("delete%s+from%s+%w+%.%w+$") then
      -- This is schema.table (partial table name)
      return {
        type = Context.Type.TABLE,
        prefix = before_cursor,
        trigger = nil,
        schema = part1,
        mode = "qualified_partial",
      }
    else
      -- This is table.column (partial column name)
      return {
        type = Context.Type.COLUMN,
        prefix = before_cursor,
        trigger = nil,
        table_ref = part1,
        mode = "qualified_partial",
      }
    end
  end

  -- 10. SELECT clause: SELECT | or SELECT E| or SELECT Emp| (column completion)
  if before_cursor_lower:match("select%s+%w*$") then
    return {
      type = Context.Type.COLUMN,
      prefix = before_cursor,
      trigger = " ",
      mode = "select",
    }
  end

  -- 11. WHERE clause: WHERE | or WHERE E| or WHERE Emp| (column completion)
  if before_cursor_lower:match("where%s+%w*$") then
    return {
      type = Context.Type.COLUMN,
      prefix = before_cursor,
      trigger = " ",
      mode = "where",
    }
  end

  -- 12. ORDER BY clause: ORDER BY | or ORDER BY E| or ORDER BY Emp|
  if before_cursor_lower:match("order%s+by%s+%w*$") then
    return {
      type = Context.Type.COLUMN,
      prefix = before_cursor,
      trigger = " ",
      mode = "order_by",
    }
  end

  -- 13. GROUP BY clause: GROUP BY | or GROUP BY E| or GROUP BY Emp|
  if before_cursor_lower:match("group%s+by%s+%w*$") then
    return {
      type = Context.Type.COLUMN,
      prefix = before_cursor,
      trigger = " ",
      mode = "group_by",
    }
  end

  -- 14. EXEC/EXECUTE: EXEC | or EXEC sp| or EXEC sp_Get| (procedure completion)
  if before_cursor_lower:match("exec%w*%s+%w*$") then
    return {
      type = Context.Type.PROCEDURE,
      prefix = before_cursor,
      trigger = " ",
      mode = "exec",
    }
  end

  -- 15. After procedure name: EXEC proc | (parameter completion)
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

  -- 16. Default: keyword completion (but try tree-sitter first for multi-line support)
  local Debug = require('ssns.debug')
  Debug.log("[CONTEXT] All regex patterns failed, attempting tree-sitter fallback")

  local regex_result = {
    type = Context.Type.KEYWORD,
    prefix = before_cursor,
    trigger = nil,
    mode = "default",
  }

  -- Try tree-sitter for better multi-line support
  local ts_result = Context.detect_with_treesitter(bufnr, line_num, col)
  if ts_result then
    -- Tree-sitter found a more specific context
    Debug.log(string.format("[CONTEXT] Returning tree-sitter context: type=%s, mode=%s, schema=%s",
      tostring(ts_result.type),
      tostring(ts_result.mode),
      tostring(ts_result.schema or "nil")))
    return ts_result
  end

  -- Fall back to keyword completion
  Debug.log("[CONTEXT] Returning keyword completion (fallback)")
  return regex_result
end

--- Detect completion context using tree-sitter (for multi-line queries)
---@param bufnr number Buffer number
---@param row number Cursor row (1-indexed)
---@param col number Cursor column (1-indexed)
---@return table? Context information (nil if tree-sitter unavailable or no context found)
function Context.detect_with_treesitter(bufnr, row, col)
  local Debug = require('ssns.debug')
  local Treesitter = require('ssns.completion.metadata.treesitter')

  Debug.log(string.format("[CONTEXT] detect_with_treesitter() called: bufnr=%d, line_num=%d, col=%d",
    bufnr, row, col))

  -- Check if tree-sitter is available
  local ts_available = Treesitter.is_available()
  Debug.log(string.format("[CONTEXT] Tree-sitter available: %s", tostring(ts_available)))

  if not ts_available then
    Debug.log("[CONTEXT] Tree-sitter not available, returning nil")
    return nil
  end

  -- Get full buffer content
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local query_text = table.concat(lines, "\n")

  -- Parse SQL
  local root = Treesitter.parse_sql(query_text)
  if not root then
    Debug.log("[CONTEXT] Tree-sitter parse returned nil")
    return nil
  end

  Debug.log("[CONTEXT] Tree-sitter parse successful")

  -- Convert to 0-indexed for tree-sitter
  local ts_row = row - 1
  local ts_col = col - 1

  -- Find node at cursor position
  local node = root:descendant_for_range(ts_row, ts_col, ts_row, ts_col)
  if not node then
    Debug.log("[CONTEXT] No node found at cursor position")
    return nil
  end

  Debug.log(string.format("[CONTEXT] Found node at cursor: type=%s", node:type()))

  -- Walk up parent chain to find statement context
  local current = node
  while current do
    local node_type = current:type()

    Debug.log(string.format("[CONTEXT] Checking parent node: type=%s", node_type))

    -- Check for FROM clause context (table completion)
    if node_type == "from_clause" or node_type == "from" then
      Debug.log("[CONTEXT] Tree-sitter detected FROM clause, extracting schema from current line")

      -- Try to extract schema qualifier from current position
      -- Look backwards from cursor for identifier.| pattern
      local current_line = lines[row] or ""
      local before_cursor = current_line:sub(1, col)
      local before_cursor_lower = before_cursor:lower()

      -- Check if cursor is after schema qualifier (schema.)
      local schema = before_cursor_lower:match("(%w+)%.$")

      if schema then
        -- Qualified FROM: FROM schema.|
        Debug.log(string.format("[CONTEXT] Schema extracted: '%s'", schema))
        return {
          type = Context.Type.TABLE,
          mode = "from_qualified",
          trigger = ".",
          prefix = before_cursor,
          schema = schema,
          filter_schema = schema,
          omit_schema = true,  -- Schema already typed
        }
      else
        -- Unqualified FROM: FROM |
        Debug.log("[CONTEXT] No schema qualifier found, returning unqualified FROM")
        return {
          type = Context.Type.TABLE,
          mode = "from",
          trigger = nil,
          prefix = before_cursor,
        }
      end
    end

    -- Check for JOIN clause context (table completion)
    if node_type:match("join") then  -- Matches inner_join, left_join, etc.
      Debug.log("[CONTEXT] Tree-sitter detected JOIN clause, extracting schema from current line")

      -- Try to extract schema qualifier from current position
      local current_line = lines[row] or ""
      local before_cursor = current_line:sub(1, col)
      local before_cursor_lower = before_cursor:lower()

      -- Check if cursor is after schema qualifier (schema.)
      local schema = before_cursor_lower:match("(%w+)%.$")

      if schema then
        -- Qualified JOIN: JOIN schema.|
        Debug.log(string.format("[CONTEXT] Schema extracted: '%s'", schema))
        return {
          type = Context.Type.TABLE,
          mode = "join_qualified",
          trigger = ".",
          prefix = before_cursor,
          schema = schema,
          filter_schema = schema,
          omit_schema = true,  -- Schema already typed
        }
      else
        -- Unqualified JOIN: JOIN |
        Debug.log("[CONTEXT] No schema qualifier found, returning unqualified JOIN")
        return {
          type = Context.Type.TABLE,
          mode = "join",
          trigger = nil,
          prefix = before_cursor,
        }
      end
    end

    -- Check for WHERE clause context (column completion)
    if node_type == "where_clause" or node_type == "where" then
      return {
        type = Context.Type.COLUMN,
        mode = "where",
        trigger = nil,
        prefix = lines[row]:sub(1, col),
      }
    end

    -- Check for SELECT clause context (column completion)
    if node_type == "select_clause" or node_type == "select" then
      return {
        type = Context.Type.COLUMN,
        mode = "select",
        trigger = nil,
        prefix = lines[row]:sub(1, col),
      }
    end

    -- Check for ORDER BY clause context (column completion)
    if node_type == "order_by_clause" or node_type == "order_by" then
      return {
        type = Context.Type.COLUMN,
        mode = "order_by",
        trigger = nil,
        prefix = lines[row]:sub(1, col),
      }
    end

    -- Check for GROUP BY clause context (column completion)
    if node_type == "group_by_clause" or node_type == "group_by" then
      return {
        type = Context.Type.COLUMN,
        mode = "group_by",
        trigger = nil,
        prefix = lines[row]:sub(1, col),
      }
    end

    -- Check for EXEC/EXECUTE context (procedure completion)
    if node_type == "execute_statement" or node_type == "exec_statement" then
      return {
        type = Context.Type.PROCEDURE,
        mode = "exec",
        trigger = nil,
        prefix = lines[row]:sub(1, col),
      }
    end

    -- Check for function call context (might be parameters)
    if node_type == "function_call" then
      -- Check if cursor is inside parentheses (parameters)
      local parent = current:parent()
      if parent and parent:type() == "arguments" then
        return {
          type = Context.Type.PARAMETER,
          mode = "function",
          trigger = nil,
          prefix = lines[row]:sub(1, col),
        }
      end
    end

    -- Check for field reference (table.column or schema.table)
    if node_type == "field_reference" or node_type == "object_reference" then
      -- This handles qualified references like "dbo.table" or "e.column"
      local text = vim.treesitter.get_node_text(current, query_text)

      -- Check if ends with dot (waiting for next part)
      if text:match("%.$") or col == current:end_() + 1 then
        -- Count dots to determine if schema.table or table.column
        local dots = 0
        for _ in text:gmatch("%.") do dots = dots + 1 end

        if dots == 1 then
          -- Could be schema.table or table.column - need parent context
          local parent = current:parent()
          if parent and (parent:type():match("from") or parent:type():match("join")) then
            -- In FROM/JOIN: schema.table context
            return {
              type = Context.Type.TABLE,
              mode = "from_qualified",
              trigger = ".",
              prefix = lines[row]:sub(1, col),
              schema = text:match("^([^%.]+)"),
            }
          else
            -- In SELECT/WHERE: table.column context
            return {
              type = Context.Type.COLUMN,
              mode = "qualified",
              trigger = ".",
              prefix = lines[row]:sub(1, col),
              table_ref = text:match("^([^%.]+)"),
            }
          end
        end
      end
    end

    -- Move to parent
    current = current:parent()
  end

  Debug.log("[CONTEXT] Tree-sitter: No specific context found, returning nil")
  -- No specific context found, return nil to use fallback
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
