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

  -- NEW: Build scope tree for alias/CTE/table resolution (Phase 2.1)
  local scope_tree = nil
  local cursor_scope = nil
  local aliases = {}
  local ctes = {}
  local tables_in_scope = nil

  -- Try to build scope tree (graceful failure if not available)
  local success, result = pcall(function()
    local ScopeTracker = require('ssns.completion.metadata.scope_tracker')
    return ScopeTracker.build_scope_tree(text, bufnr, nil) -- connection optional
  end)

  if success and result then
    scope_tree = result
    Debug.log("[CONTEXT] Scope tree built successfully")

    -- Get scope at cursor position
    local cursor_pos = {row, col}
    local ScopeTracker = require('ssns.completion.metadata.scope_tracker')
    cursor_scope = ScopeTracker.get_scope_at_cursor(scope_tree, cursor_pos)

    if cursor_scope then
      Debug.log(string.format("[CONTEXT] Cursor scope type: %s", cursor_scope.type))
    end

    -- Extract aliases at cursor position
    local alias_success, alias_result = pcall(function()
      return ScopeTracker.get_available_aliases(scope_tree, cursor_pos)
    end)

    if alias_success and alias_result then
      aliases = alias_result
      Debug.log(string.format("[CONTEXT] Aliases at cursor: %d", vim.tbl_count(aliases)))
    end

    -- Extract CTEs at cursor position
    local cte_success, cte_result = pcall(function()
      return ScopeTracker.get_available_ctes(scope_tree, cursor_pos)
    end)

    if cte_success and cte_result then
      ctes = cte_result
      Debug.log(string.format("[CONTEXT] CTEs at cursor: %d", vim.tbl_count(ctes)))
    end

    -- Extract table references in current scope
    if cursor_scope and cursor_scope.aliases then
      tables_in_scope = {}
      for alias, table_name in pairs(cursor_scope.aliases) do
        table.insert(tables_in_scope, {
          alias = alias,
          table = table_name,
          scope = cursor_scope.type
        })
      end
      Debug.log(string.format("[CONTEXT] Tables in scope: %d", #tables_in_scope))
    end
  else
    Debug.log("[CONTEXT] Scope tree building failed or unavailable, continuing without scope info")
  end

  -- Store scope info for handlers to access
  Context._current_scope_tree = scope_tree
  Context._current_aliases = aliases
  Context._current_ctes = ctes
  Context._current_tables_in_scope = tables_in_scope

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

  -- Get text before cursor for prefix extraction
  local before_cursor = lines[row]:sub(1, col)

  -- Step 1: Check for function parameter context (NEW)
  local func_context = Context._detect_function_parameter_context(cursor_node, lines, row, col)
  if func_context then
    Debug.log(string.format("[CONTEXT] Function parameter detected: %s", func_context.function_name or "unknown"))
    return func_context
  end

  -- Step 2: Find containing statement (boundary)
  local statement_node = Context._find_containing_statement(cursor_node)
  if not statement_node then
    Debug.log("[CONTEXT] No containing statement found")
    local context = { type = Context.Type.UNKNOWN, prefix = before_cursor }
    -- Inject scope information (Phase 2.1)
    context.scope_tree = scope_tree
    context.tables_in_scope = tables_in_scope
    context.aliases = aliases
    context.ctes = ctes
    return context
  end

  -- Step 3: Extract keywords recursively from parent chain (NEW)
  local query_text = table.concat(lines, "\n")
  local keyword_stack = Context._extract_keywords_recursive(cursor_node, query_text, statement_node)

  -- Step 4: Determine context from keywords (NEW)
  if #keyword_stack > 0 then
    local context = Context._determine_context_from_keywords(keyword_stack, cursor_node, lines, row, col)
    if context then
      return context
    end
  end

  -- Step 5: Fallback to unknown context
  Debug.log("[CONTEXT] No valid context determined, returning UNKNOWN")
  local context = {
    type = Context.Type.UNKNOWN,
    prefix = before_cursor,
  }
  -- Inject scope information (Phase 2.1)
  context.scope_tree = scope_tree
  context.tables_in_scope = tables_in_scope
  context.aliases = aliases
  context.ctes = ctes
  return context
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

  -- Check for 3-part name: database.schema. (cross-database table completion)
  local db, schema = before_cursor_lower:match("(%w+)%.(%w+)%.$")
  if db and schema then
    Debug.log(string.format("[CONTEXT] FROM with cross-db qualifier: database='%s', schema='%s'", db, schema))
    local context = {
      type = Context.Type.TABLE,
      mode = "from_cross_db_qualified",
      trigger = ".",
      prefix = before_cursor,
      database = db,
      schema = schema,
      filter_database = db,
      filter_schema = schema,
      omit_schema = true,
    }
    -- Inject scope information (Phase 2.1)
    context.scope_tree = Context._current_scope_tree
    context.tables_in_scope = Context._current_tables_in_scope
    context.aliases = Context._current_aliases
    context.ctes = Context._current_ctes
    return context
  end

  -- Check for 2-part name: qualifier. (could be database. OR schema.)
  local qualifier = before_cursor_lower:match("(%w+)%.$")
  if qualifier then
    -- Heuristic: Check if qualifier is a known schema name
    local known_schemas = { "dbo", "hr", "public", "sys", "information_schema", "guest" }
    local is_schema = false
    for _, s in ipairs(known_schemas) do
      if qualifier == s:lower() then
        is_schema = true
        break
      end
    end

    if is_schema then
      -- It's a schema - return TABLE context
      Debug.log(string.format("[CONTEXT] FROM with schema qualifier: '%s'", qualifier))
      local context = {
        type = Context.Type.TABLE,
        mode = "from_qualified",
        trigger = ".",
        prefix = before_cursor,
        schema = qualifier,
        filter_schema = qualifier,
        omit_schema = true,
      }
      -- Inject scope information (Phase 2.1)
      context.scope_tree = Context._current_scope_tree
      context.tables_in_scope = Context._current_tables_in_scope
      context.aliases = Context._current_aliases
      context.ctes = Context._current_ctes
      return context
    else
      -- Assume it's a database - return SCHEMA context
      Debug.log(string.format("[CONTEXT] FROM with database qualifier: '%s'", qualifier))
      local context = {
        type = Context.Type.SCHEMA,
        mode = "from_cross_db",
        trigger = ".",
        prefix = before_cursor,
        database = qualifier,
        filter_database = qualifier,
      }
      -- Inject scope information (Phase 2.1)
      context.scope_tree = Context._current_scope_tree
      context.tables_in_scope = Context._current_tables_in_scope
      context.aliases = Context._current_aliases
      context.ctes = Context._current_ctes
      return context
    end
  else
    -- No qualifier - return TABLE context
    Debug.log("[CONTEXT] FROM without qualifier")
    local context = {
      type = Context.Type.TABLE,
      mode = "from",
      trigger = nil,
      prefix = before_cursor,
    }
    -- Inject scope information (Phase 2.1)
    context.scope_tree = Context._current_scope_tree
    context.tables_in_scope = Context._current_tables_in_scope
    context.aliases = Context._current_aliases
    context.ctes = Context._current_ctes
    return context
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

  -- Check for 3-part name: database.schema.
  local db, schema = before_cursor_lower:match("(%w+)%.(%w+)%.$")
  if db and schema then
    Debug.log(string.format("[CONTEXT] JOIN with cross-db qualifier: database='%s', schema='%s'", db, schema))
    local context = {
      type = Context.Type.TABLE,
      mode = "join_cross_db_qualified",
      trigger = ".",
      prefix = before_cursor,
      database = db,
      schema = schema,
      filter_database = db,
      filter_schema = schema,
      omit_schema = true,
    }
    -- Inject scope information (Phase 2.1)
    context.scope_tree = Context._current_scope_tree
    context.tables_in_scope = Context._current_tables_in_scope
    context.aliases = Context._current_aliases
    context.ctes = Context._current_ctes
    return context
  end

  -- Check for 2-part name: qualifier.
  local qualifier = before_cursor_lower:match("(%w+)%.$")
  if qualifier then
    local known_schemas = { "dbo", "hr", "public", "sys", "information_schema", "guest" }
    local is_schema = false
    for _, s in ipairs(known_schemas) do
      if qualifier == s:lower() then
        is_schema = true
        break
      end
    end

    if is_schema then
      Debug.log(string.format("[CONTEXT] JOIN with schema qualifier: '%s'", qualifier))
      local context = {
        type = Context.Type.TABLE,
        mode = "join_qualified",
        trigger = ".",
        prefix = before_cursor,
        schema = qualifier,
        filter_schema = qualifier,
        omit_schema = true,
      }
      -- Inject scope information (Phase 2.1)
      context.scope_tree = Context._current_scope_tree
      context.tables_in_scope = Context._current_tables_in_scope
      context.aliases = Context._current_aliases
      context.ctes = Context._current_ctes
      return context
    else
      Debug.log(string.format("[CONTEXT] JOIN with database qualifier: '%s'", qualifier))
      local context = {
        type = Context.Type.SCHEMA,
        mode = "join_cross_db",
        trigger = ".",
        prefix = before_cursor,
        database = qualifier,
        filter_database = qualifier,
      }
      -- Inject scope information (Phase 2.1)
      context.scope_tree = Context._current_scope_tree
      context.tables_in_scope = Context._current_tables_in_scope
      context.aliases = Context._current_aliases
      context.ctes = Context._current_ctes
      return context
    end
  else
    Debug.log("[CONTEXT] JOIN without qualifier")
    local context = {
      type = Context.Type.TABLE,
      mode = "join",
      trigger = nil,
      prefix = before_cursor,
    }
    -- Inject scope information (Phase 2.1)
    context.scope_tree = Context._current_scope_tree
    context.tables_in_scope = Context._current_tables_in_scope
    context.aliases = Context._current_aliases
    context.ctes = Context._current_ctes
    return context
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
  local before_cursor_lower = before_cursor:lower()

  -- NEW: Check for qualified table reference: schema.table.
  local schema, table_name = before_cursor_lower:match("(%w+)%.(%w+)%.$")
  if schema and table_name then
    Debug.log(string.format("[CONTEXT] WHERE with qualified reference: %s.%s", schema, table_name))
    local context = {
      type = Context.Type.COLUMN,
      mode = "where_qualified",
      trigger = ".",
      prefix = before_cursor,
      table_ref = schema .. "." .. table_name,
      filter_table = table_name,
      omit_table = true,
    }
    context.scope_tree = Context._current_scope_tree
    context.tables_in_scope = Context._current_tables_in_scope
    context.aliases = Context._current_aliases
    context.ctes = Context._current_ctes
    return context
  end

  -- NEW: Check for unqualified table/alias reference: alias. or table.
  local table_or_alias = before_cursor_lower:match("(%w+)%.$")
  if table_or_alias then
    -- Check if it's a known alias in scope
    local is_known_alias = Context._current_aliases and Context._current_aliases[table_or_alias]

    -- Check if it's a known table in scope
    local is_known_table = false
    if Context._current_tables_in_scope then
      for _, tbl in ipairs(Context._current_tables_in_scope) do
        local tbl_name = tbl.table or tbl.name or ""
        if tbl_name:lower() == table_or_alias then
          is_known_table = true
          break
        end
      end
    end

    if is_known_alias or is_known_table then
      Debug.log(string.format("[CONTEXT] WHERE with alias/table reference: '%s' (alias=%s, table=%s)",
        table_or_alias, tostring(is_known_alias ~= nil), tostring(is_known_table)))
      local context = {
        type = Context.Type.COLUMN,
        mode = "where_qualified",
        trigger = ".",
        prefix = before_cursor,
        table_ref = table_or_alias,
        filter_table = table_or_alias,
        omit_table = true,
      }
      context.scope_tree = Context._current_scope_tree
      context.tables_in_scope = Context._current_tables_in_scope
      context.aliases = Context._current_aliases
      context.ctes = Context._current_ctes
      return context
    else
      Debug.log(string.format("[CONTEXT] WHERE reference '%s' not found in aliases/tables", table_or_alias))
    end
  end

  -- Default: WHERE context without qualification (original behavior)
  local context = {
    type = Context.Type.COLUMN,
    mode = "where",
    trigger = nil,
    prefix = before_cursor,
  }
  -- Inject scope information (Phase 2.1)
  context.scope_tree = Context._current_scope_tree
  context.tables_in_scope = Context._current_tables_in_scope
  context.aliases = Context._current_aliases
  context.ctes = Context._current_ctes
  return context
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
  local before_cursor_lower = before_cursor:lower()

  -- NEW: Check for qualified table reference: schema.table. or alias.
  local schema, table_name = before_cursor_lower:match("(%w+)%.(%w+)%.$")
  if schema and table_name then
    Debug.log(string.format("[CONTEXT] SELECT with qualified table: schema='%s', table='%s'", schema, table_name))
    local context = {
      type = Context.Type.COLUMN,
      mode = "select_qualified",
      trigger = ".",
      prefix = before_cursor,
      table_ref = schema .. "." .. table_name,
      schema = schema,
      filter_table = table_name,
      omit_table = true,
    }
    -- Inject scope information (Phase 2.1)
    context.scope_tree = Context._current_scope_tree
    context.tables_in_scope = Context._current_tables_in_scope
    context.aliases = Context._current_aliases
    context.ctes = Context._current_ctes
    return context
  end

  -- NEW: Check for unqualified table/alias reference: table. or alias.
  local table_or_alias = before_cursor_lower:match("(%w+)%.$")
  if table_or_alias then
    Debug.log(string.format("[CONTEXT] SELECT with table/alias reference: '%s'", table_or_alias))
    local context = {
      type = Context.Type.COLUMN,
      mode = "select_qualified",
      trigger = ".",
      prefix = before_cursor,
      table_ref = table_or_alias,
      filter_table = table_or_alias,
      omit_table = true,
    }
    -- Inject scope information (Phase 2.1)
    context.scope_tree = Context._current_scope_tree
    context.tables_in_scope = Context._current_tables_in_scope
    context.aliases = Context._current_aliases
    context.ctes = Context._current_ctes
    return context
  end

  -- EXISTING: Check if we're after FROM (which means we're in FROM clause, not SELECT list)
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
  local context = {
    type = Context.Type.COLUMN,
    mode = "select",
    trigger = nil,
    prefix = before_cursor,
  }
  -- Inject scope information (Phase 2.1)
  context.scope_tree = Context._current_scope_tree
  context.tables_in_scope = Context._current_tables_in_scope
  context.aliases = Context._current_aliases
  context.ctes = Context._current_ctes
  return context
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
    local context = {
      type = Context.Type.TABLE,
      mode = "insert_qualified",
      trigger = ".",
      prefix = before_cursor,
      schema = schema,
      filter_schema = schema,
      omit_schema = true,
    }
    -- Inject scope information (Phase 2.1)
    context.scope_tree = Context._current_scope_tree
    context.tables_in_scope = Context._current_tables_in_scope
    context.aliases = Context._current_aliases
    context.ctes = Context._current_ctes
    return context
  else
    local context = {
      type = Context.Type.TABLE,
      mode = "insert",
      trigger = nil,
      prefix = before_cursor,
    }
    -- Inject scope information (Phase 2.1)
    context.scope_tree = Context._current_scope_tree
    context.tables_in_scope = Context._current_tables_in_scope
    context.aliases = Context._current_aliases
    context.ctes = Context._current_ctes
    return context
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
    local context = {
      type = Context.Type.TABLE,
      mode = "update_qualified",
      trigger = ".",
      prefix = before_cursor,
      schema = schema,
      filter_schema = schema,
      omit_schema = true,
    }
    -- Inject scope information (Phase 2.1)
    context.scope_tree = Context._current_scope_tree
    context.tables_in_scope = Context._current_tables_in_scope
    context.aliases = Context._current_aliases
    context.ctes = Context._current_ctes
    return context
  else
    local context = {
      type = Context.Type.TABLE,
      mode = "update",
      trigger = nil,
      prefix = before_cursor,
    }
    -- Inject scope information (Phase 2.1)
    context.scope_tree = Context._current_scope_tree
    context.tables_in_scope = Context._current_tables_in_scope
    context.aliases = Context._current_aliases
    context.ctes = Context._current_ctes
    return context
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
    local context = {
      type = Context.Type.TABLE,
      mode = "delete_qualified",
      trigger = ".",
      prefix = before_cursor,
      schema = schema,
      filter_schema = schema,
      omit_schema = true,
    }
    -- Inject scope information (Phase 2.1)
    context.scope_tree = Context._current_scope_tree
    context.tables_in_scope = Context._current_tables_in_scope
    context.aliases = Context._current_aliases
    context.ctes = Context._current_ctes
    return context
  else
    local context = {
      type = Context.Type.TABLE,
      mode = "delete",
      trigger = nil,
      prefix = before_cursor,
    }
    -- Inject scope information (Phase 2.1)
    context.scope_tree = Context._current_scope_tree
    context.tables_in_scope = Context._current_tables_in_scope
    context.aliases = Context._current_aliases
    context.ctes = Context._current_ctes
    return context
  end
end

---Extract SQL keyword from tree-sitter node type
---@param node_type string Tree-sitter node type (e.g., "keyword_where", "where_clause")
---@return string? keyword Uppercase SQL keyword (e.g., "WHERE") or nil
function Context._extract_keyword_from_type(node_type)
  -- Pattern 1: keyword_ prefix (e.g., "keyword_where" -> "WHERE")
  local keyword = node_type:match("^keyword_(.+)$")
  if keyword then
    return keyword:upper()
  end

  -- Pattern 2: _clause suffix (e.g., "where_clause" -> "WHERE")
  keyword = node_type:match("^(.+)_clause$")
  if keyword then
    return keyword:upper()
  end

  -- Pattern 3: Direct keyword mappings
  local keyword_map = {
    select = "SELECT",
    from = "FROM",
    where = "WHERE",
    join = "JOIN",
    inner_join = "INNER JOIN",
    left_join = "LEFT JOIN",
    right_join = "RIGHT JOIN",
    insert_statement = "INSERT",
    update_statement = "UPDATE",
    delete_statement = "DELETE",
  }

  return keyword_map[node_type]
end

---Extract SQL keyword from node's text content
---@param node table Tree-sitter node
---@param query_text string Full query text
---@return string? keyword Uppercase SQL keyword or nil
function Context._extract_keyword_from_text(node, query_text)
  -- Get node text
  local ok, text = pcall(vim.treesitter.get_node_text, node, query_text)
  if not ok or not text then
    return nil
  end

  -- Trim leading whitespace, convert to uppercase
  text = text:match("^%s*(.*)"):upper()

  -- Check if text starts with any SQL keyword
  local keywords = {
    "INNER JOIN", "LEFT JOIN", "RIGHT JOIN", "OUTER JOIN", "FULL JOIN",
    "SELECT", "FROM", "WHERE", "JOIN", "INSERT", "UPDATE", "DELETE",
    "GROUP BY", "ORDER BY", "HAVING"
  }

  for _, kw in ipairs(keywords) do
    if text:sub(1, #kw) == kw then
      return kw
    end
  end

  return nil
end

---Combined keyword detection (try type first, then text)
---@param node table Tree-sitter node
---@param query_text string Full query text
---@return string? keyword Uppercase SQL keyword or nil
function Context._detect_sql_keyword(node, query_text)
  -- Fast path: try node type first
  local keyword = Context._extract_keyword_from_type(node:type())
  if keyword then
    return keyword
  end

  -- Fallback: check node text content
  return Context._extract_keyword_from_text(node, query_text)
end

---Find the containing statement node (boundary for scope)
---@param node table Tree-sitter node
---@return table? statement_node Statement node or nil
function Context._find_containing_statement(node)
  local current = node
  while current do
    local node_type = current:type()
    if node_type == "statement" or
       node_type == "select_statement" or
       node_type == "insert_statement" or
       node_type == "update_statement" or
       node_type == "delete_statement" then
      return current
    end
    current = current:parent()
  end
  return nil
end

---Walk parent chain collecting SQL keywords
---@param cursor_node table Tree-sitter node at cursor
---@param query_text string Full query text
---@param statement_boundary table? Statement node to stop at
---@return table keyword_stack Array of {keyword, node, depth}
function Context._extract_keywords_recursive(cursor_node, query_text, statement_boundary)
  local Debug = require('ssns.debug')
  local keyword_stack = {}
  local current = cursor_node
  local depth = 0
  local MAX_DEPTH = 20

  Debug.log(string.format("[CONTEXT] Recursive keyword search: starting at node type='%s'", cursor_node:type()))

  while current and depth < MAX_DEPTH do
    -- Stop at statement boundary
    if statement_boundary and current == statement_boundary then
      break
    end

    -- Detect keyword
    local keyword = Context._detect_sql_keyword(current, query_text)
    if keyword then
      table.insert(keyword_stack, {
        keyword = keyword,
        node = current,
        depth = depth,
      })
    end

    -- Move to parent
    current = current:parent()
    depth = depth + 1
  end

  Debug.log(string.format("[CONTEXT] Keywords found: %d", #keyword_stack))
  for i, kw_info in ipairs(keyword_stack) do
    Debug.log(string.format("[CONTEXT]   [%d] %s (depth=%d, node=%s)",
      i, kw_info.keyword, kw_info.depth, kw_info.node:type()))
  end

  return keyword_stack
end

---Detect if cursor is inside function call parentheses (NEW FEATURE)
---@param cursor_node table Tree-sitter node at cursor
---@param lines table Buffer lines
---@param row number Cursor row (1-indexed)
---@param col number Cursor column (1-indexed)
---@return table? context Context table or nil
function Context._detect_function_parameter_context(cursor_node, lines, row, col)
  local Debug = require('ssns.debug')
  local current = cursor_node
  local depth = 0
  local MAX_DEPTH = 10

  while current and depth < MAX_DEPTH do
    local node_type = current:type()

    -- Check if we're in argument/parameter list
    if node_type == "argument_list" or node_type == "parameter_list" then
      -- Check parent is a function
      local parent = current:parent()
      if parent then
        local parent_type = parent:type()
        if parent_type == "invocation" or parent_type:match("function") then
          -- Extract function name from first identifier child
          local func_name = nil
          for child in parent:iter_children() do
            if child:type() == "identifier" then
              local ok, name = pcall(vim.treesitter.get_node_text, child, table.concat(lines, "\n"))
              if ok then
                func_name = name
              end
              break
            end
          end

          if func_name then
            Debug.log(string.format("[CONTEXT] Function parameter context detected: %s", func_name))

            local current_line = lines[row] or ""
            local before_cursor = current_line:sub(1, col)

            local context = {
              type = Context.Type.COLUMN,
              mode = "function_parameter",
              function_name = func_name,
              trigger = nil,
              prefix = before_cursor,
            }
            -- Inject scope information (Phase 2.1)
            context.scope_tree = Context._current_scope_tree
            context.tables_in_scope = Context._current_tables_in_scope
            context.aliases = Context._current_aliases
            context.ctes = Context._current_ctes
            return context
          end
        end
      end
    end

    current = current:parent()
    depth = depth + 1
  end

  return nil
end

---Map keywords to context by checking closest keyword first
---@param keyword_stack table Array of {keyword, node, depth}
---@param cursor_node table Tree-sitter node at cursor
---@param lines table Buffer lines
---@param row number Cursor row (1-indexed)
---@param col number Cursor column (1-indexed)
---@return table? context Context table or nil
function Context._determine_context_from_keywords(keyword_stack, cursor_node, lines, row, col)
  local Debug = require('ssns.debug')

  -- Iterate keyword_stack (already sorted closest to farthest)
  for i, kw_info in ipairs(keyword_stack) do
    local keyword = kw_info.keyword

    Debug.log(string.format("[CONTEXT] Checking keyword: %s", keyword))

    -- WHERE or HAVING
    if keyword == "WHERE" or keyword == "HAVING" then
      local context = Context._handle_where_context(kw_info.node, lines, row, col)
      if context then
        Debug.log(string.format("[CONTEXT] Context determined from keyword '%s': type=%s, mode=%s",
          keyword, context.type, context.mode or "none"))
        return context
      end

    -- FROM
    elseif keyword == "FROM" then
      local context = Context._handle_from_context(kw_info.node, lines, row, col)
      if context then
        Debug.log(string.format("[CONTEXT] Context determined from keyword '%s': type=%s, mode=%s",
          keyword, context.type, context.mode or "none"))
        return context
      end

    -- JOIN (any type)
    elseif keyword:match("JOIN") then
      local context = Context._handle_join_context(kw_info.node, lines, row, col)
      if context then
        Debug.log(string.format("[CONTEXT] Context determined from keyword '%s': type=%s, mode=%s",
          keyword, context.type, context.mode or "none"))
        return context
      end

    -- SELECT
    elseif keyword == "SELECT" then
      -- Check if FROM or JOIN exists earlier in stack (lower index = closer to cursor)
      local has_from_or_join = false
      for j = 1, i - 1 do
        local earlier_kw = keyword_stack[j].keyword
        if earlier_kw == "FROM" or earlier_kw:match("JOIN") then
          has_from_or_join = true
          break
        end
      end

      -- If FROM/JOIN takes precedence, skip SELECT
      if not has_from_or_join then
        local context = Context._handle_select_context(kw_info.node, cursor_node, lines, row, col)
        if context then
          Debug.log(string.format("[CONTEXT] Context determined from keyword '%s': type=%s, mode=%s",
            keyword, context.type, context.mode or "none"))
          return context
        end
      end

    -- INSERT
    elseif keyword == "INSERT" then
      local context = Context._handle_insert_context(kw_info.node, lines, row, col)
      if context then
        Debug.log(string.format("[CONTEXT] Context determined from keyword '%s': type=%s, mode=%s",
          keyword, context.type, context.mode or "none"))
        return context
      end

    -- UPDATE
    elseif keyword == "UPDATE" then
      local context = Context._handle_update_context(kw_info.node, lines, row, col)
      if context then
        Debug.log(string.format("[CONTEXT] Context determined from keyword '%s': type=%s, mode=%s",
          keyword, context.type, context.mode or "none"))
        return context
      end

    -- DELETE
    elseif keyword == "DELETE" then
      local context = Context._handle_delete_context(kw_info.node, lines, row, col)
      if context then
        Debug.log(string.format("[CONTEXT] Context determined from keyword '%s': type=%s, mode=%s",
          keyword, context.type, context.mode or "none"))
        return context
      end
    end
  end

  return nil
end

---Find the last SQL keyword node that precedes the cursor position
---@param root_node any Tree-sitter root node
---@param cursor_row number 0-indexed row
---@param cursor_col number 0-indexed column
---@param lines table|nil Buffer lines (optional, for extracting node text without buffer dependency)
---@return string|nil keyword_type The type of the last keyword found (where, from, select, join, etc.)
---@return any|nil keyword_node The actual node
function Context._find_last_keyword_before_cursor(root_node, cursor_row, cursor_col, lines)
  local Debug = require('ssns.debug')
  local last_keyword_type = nil
  local last_keyword_node = nil
  local last_keyword_start_pos = {-1, -1}  -- {row, col} - use START position, not END

  -- SQL keyword node types to look for
  local keyword_types = {
    ["keyword_where"] = "where",
    ["keyword_from"] = "from",
    ["keyword_select"] = "select",
    ["keyword_join"] = "join",
    ["keyword_inner"] = "join",
    ["keyword_left"] = "join",
    ["keyword_right"] = "join",
    ["keyword_outer"] = "join",
    ["keyword_cross"] = "join",
    ["keyword_and"] = "where",  -- AND/OR are WHERE clause continuations
    ["keyword_or"] = "where",
    ["where"] = "where",
    ["where_clause"] = "where",
    ["from"] = "from",
    ["from_clause"] = "from",
    ["select"] = "select",
    ["select_clause"] = "select",
  }

  -- Recursive function to traverse all nodes
  local function traverse(node)
    if not node then return end

    local node_type = node:type()
    local start_row, start_col, end_row, end_col = node:range()

    -- Check if this node ends before cursor
    local ends_before_cursor = (end_row < cursor_row) or
                               (end_row == cursor_row and end_col <= cursor_col)

    -- Check if this is a keyword node type
    local keyword_context = keyword_types[node_type]

    -- Also check node text for keyword patterns (handles cases where grammar doesn't create keyword_ nodes)
    if not keyword_context and ends_before_cursor then
      -- Extract node text safely (from lines if available, otherwise use pcall with get_node_text)
      local node_text = ""
      if lines then
        -- Extract text from lines table using node range (0-indexed)
        if start_row == end_row then
          -- Single-line node
          local line = lines[start_row + 1]  -- lines is 1-indexed
          if line then
            node_text = line:sub(start_col + 1, end_col):lower()
          end
        else
          -- Multi-line node (rare for keywords, but handle it)
          local parts = {}
          for i = start_row, end_row do
            local line = lines[i + 1]  -- lines is 1-indexed
            if line then
              if i == start_row then
                table.insert(parts, line:sub(start_col + 1))
              elseif i == end_row then
                table.insert(parts, line:sub(1, end_col))
              else
                table.insert(parts, line)
              end
            end
          end
          node_text = table.concat(parts, "\n"):lower()
        end
      else
        -- Fallback to get_node_text with pcall (buffer-dependent)
        local success, result = pcall(function()
          return vim.treesitter.get_node_text(node, 0)
        end)
        if success and result then
          node_text = result:lower()
        end
      end

      if node_text == "where" then keyword_context = "where"
      elseif node_text == "from" then keyword_context = "from"
      elseif node_text == "select" then keyword_context = "select"
      elseif node_text == "join" or node_text == "inner" or node_text == "left" or
             node_text == "right" or node_text == "cross" then keyword_context = "join"
      elseif node_text == "and" or node_text == "or" then keyword_context = "where"
      end
    end

    if keyword_context and ends_before_cursor then
      -- Check if this keyword STARTS later than our current last keyword
      -- (the keyword that starts latest and ends before cursor is most relevant)
      local is_later = (start_row > last_keyword_start_pos[1]) or
                       (start_row == last_keyword_start_pos[1] and start_col > last_keyword_start_pos[2])

      if is_later then
        last_keyword_type = keyword_context
        last_keyword_node = node
        last_keyword_start_pos = {start_row, start_col}
        Debug.log(string.format("[CONTEXT] Found keyword '%s' at (%d,%d)-(%d,%d)",
          node_type, start_row, start_col, end_row, end_col))
      end
    end

    -- Recurse into children
    for child in node:iter_children() do
      traverse(child)
    end
  end

  traverse(root_node)

  if last_keyword_type then
    Debug.log(string.format("[CONTEXT] Last keyword before cursor: %s", last_keyword_type))
  end

  return last_keyword_type, last_keyword_node
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

  -- Step 1: Check ERROR node's own children for keywords (PRIORITY)
  local has_where_keyword = false
  local has_join_keyword = false
  local has_and_or_keyword = false

  for child in error_node:iter_children() do
    local child_type = child:type()

    if child_type == "keyword_where" then
      has_where_keyword = true
      Debug.log("[CONTEXT] ERROR contains WHERE keyword")
    elseif child_type == "keyword_and" or child_type == "keyword_or" then
      has_and_or_keyword = true
      Debug.log(string.format("[CONTEXT] ERROR contains %s keyword", child_type))
    elseif child_type == "keyword_join" or child_type:match("keyword_.*join") then
      has_join_keyword = true
      Debug.log(string.format("[CONTEXT] ERROR contains JOIN keyword: %s", child_type))
    end
  end

  -- If ERROR contains WHERE/AND/OR keywords → return COLUMN context
  if has_where_keyword or has_and_or_keyword then
    Debug.log("[CONTEXT] ERROR node has WHERE/AND/OR, calling _handle_where_context()")
    return Context._handle_where_context(error_node, lines, row, col)
  end

  -- If ERROR contains JOIN keyword → return TABLE context
  if has_join_keyword then
    Debug.log("[CONTEXT] ERROR node has JOIN keyword, calling _handle_join_context()")
    return Context._handle_join_context(error_node, lines, row, col)
  end

  -- NEW: Use tree-sitter traversal to find the last keyword before cursor
  -- Get the root node for traversal
  local root_node = error_node
  while root_node:parent() do
    root_node = root_node:parent()
  end

  -- Find the last SQL keyword that precedes the cursor
  local last_keyword, keyword_node = Context._find_last_keyword_before_cursor(root_node, row - 1, col, lines)

  if last_keyword == "where" then
    Debug.log("[CONTEXT] Tree-sitter found WHERE context before cursor")
    return Context._handle_where_context(error_node, lines, row, col)
  elseif last_keyword == "join" then
    Debug.log("[CONTEXT] Tree-sitter found JOIN context before cursor")
    return Context._handle_join_context(error_node, lines, row, col)
  elseif last_keyword == "from" then
    Debug.log("[CONTEXT] Tree-sitter found FROM context before cursor")
    return Context._handle_from_context(keyword_node or error_node, lines, row, col)
  elseif last_keyword == "select" then
    Debug.log("[CONTEXT] Tree-sitter found SELECT context before cursor")
    return Context._handle_select_context(keyword_node or error_node, error_node, lines, row, col)
  end

  Debug.log("[CONTEXT] No keywords found via tree-sitter, checking previous sibling")

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
