---Scope tracker for SQL query parsing
---Handles nested queries, subqueries, CTEs, and derived tables for accurate alias/table resolution
---Uses Tree-sitter for robust parsing with regex fallback
---@class ScopeTracker
local ScopeTracker = {}

local Debug = require('ssns.debug')

-- Helper: Conditional debug logging based on config
local function debug_log(message)
  local Config = require('ssns.config')
  local config = Config.get()
  if config.completion and config.completion.debug then
    Debug.log("[SCOPE] " .. message)
  end
end

---Helper function to recursively find nodes of specified types within a node (including ERROR nodes)
---@param node table Tree-sitter node to search
---@param target_types string[] Array of node types to find (can include patterns)
---@param results table[] Array to collect results (modified in place)
---@return table[] results Array of matching nodes
function ScopeTracker._find_nodes_recursive(node, target_types, results)
  results = results or {}

  if not node then return results end

  local node_type = node:type()

  -- Check if this node is one of our target types
  for _, target in ipairs(target_types) do
    if node_type == target or node_type:match(target) then
      table.insert(results, node)
      debug_log(string.format("[SCOPE] _find_nodes_recursive: found %s node", node_type))
    end
  end

  -- Always recurse into children (including ERROR nodes)
  for child in node:iter_children() do
    ScopeTracker._find_nodes_recursive(child, target_types, results)
  end

  return results
end

---@class QueryScope
---@field type string Scope type: "global", "cte", "subquery", "derived", "main"
---@field start_pos table {row, col} Start position in buffer (1-indexed)
---@field end_pos table {row, col} End position in buffer (1-indexed)
---@field aliases table<string, string> Alias -> table mapping in this scope
---@field ctes table<string, table> CTE name -> CTE info mapping
---@field parent QueryScope? Parent scope (nil for global)
---@field children QueryScope[] Child scopes
---@field temp_tables table<string, table> Temp table name -> table info (placeholder for Phase 10.5)

---Build scope tree from SQL query text
---Analyzes nested queries, CTEs, and derived tables to track aliases at each scope level
---@param query_text string SQL query (can be multi-line)
---@param bufnr number Buffer number
---@param connection table? Optional connection context for CTE asterisk expansion
---@return QueryScope global_scope Root scope containing all nested scopes
function ScopeTracker.build_scope_tree(query_text, bufnr, connection)
  debug_log("build_scope_tree START")
  debug_log("Query text: " .. query_text:sub(1, 200))  -- First 200 chars

  -- Step 1: Try Tree-sitter based parsing
  local Treesitter = require('ssns.completion.metadata.treesitter')
  local root = Treesitter.parse_sql(query_text)

  if not root then
    debug_log("Tree-sitter parsing failed, using fallback scope")
    -- Fallback: Create simple global scope with flat aliases
    return ScopeTracker._create_fallback_scope(query_text)
  end

  -- Step 2: Create global scope
  -- Calculate line count from query text if bufnr is invalid
  local line_count
  if bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    line_count = vim.api.nvim_buf_line_count(bufnr)
  else
    -- Count lines in query_text
    local _, count = query_text:gsub("\n", "\n")
    line_count = count + 1  -- Add 1 for the last line
  end

  local global_scope = {
    type = "global",
    start_pos = { 1, 1 },  -- 1-indexed (Neovim convention)
    end_pos = { line_count, 999999 },
    aliases = {},
    ctes = {},
    parent = nil,
    children = {},
    temp_tables = {}, -- Placeholder for Phase 10.5
  }

  -- Step 3: Walk AST to find scopes
  ScopeTracker._build_scope_tree_recursive(root, query_text, global_scope, bufnr, connection)

  debug_log("Scope tree built")
  debug_log("GlobalScope children count: " .. #global_scope.children)
  debug_log("GlobalScope aliases: " .. vim.inspect(global_scope.aliases))

  return global_scope
end

---Recursively build scope tree by walking AST
---@param node table Tree-sitter node
---@param query_text string Original query text
---@param parent_scope QueryScope Parent scope to attach children to
---@param bufnr number Buffer number
---@param connection table? Optional connection context
function ScopeTracker._build_scope_tree_recursive(node, query_text, parent_scope, bufnr, connection)
  if not node then
    return
  end

  local node_type = node:type()

  -- Process different node types
  if node_type == "statement" then
    -- FIRST: Check if this statement has CTEs (direct cte children)
    local has_ctes = false
    for child in node:iter_children() do
      local child_type = child:type()

      -- Search ERROR nodes for cte
      if child_type == "ERROR" then
        debug_log("[SCOPE] Found ERROR node in _build_scope_tree_recursive (CTE check), searching inside")
        local found_ctes = ScopeTracker._find_nodes_recursive(child, {"cte"}, {})
        if #found_ctes > 0 then
          has_ctes = true
          break
        end
        goto continue
      end

      if child_type == "cte" then
        has_ctes = true
        break
      end

      ::continue::
    end

    -- If statement has CTEs, extract them to parent scope
    -- (CTEs are visible to the entire query, not scoped to the SELECT)
    if has_ctes then
      debug_log("Statement has CTE children, extracting to parent scope")
      for child in node:iter_children() do
        local child_type = child:type()

        -- Search ERROR nodes for cte
        if child_type == "ERROR" then
          debug_log("[SCOPE] Found ERROR node in _build_scope_tree_recursive (CTE extraction), searching inside")
          local found_ctes = ScopeTracker._find_nodes_recursive(child, {"cte"}, {})
          for _, cte_node in ipairs(found_ctes) do
            debug_log("[SCOPE] Found CTE inside ERROR node")
            ScopeTracker._extract_single_cte(cte_node, query_text, parent_scope, bufnr, connection)
          end
          goto continue
        end

        if child_type == "cte" then
          ScopeTracker._extract_single_cte(child, query_text, parent_scope, bufnr, connection)
        end

        ::continue::
      end
    end

    -- THEN: Process as a SELECT scope
    ScopeTracker._extract_select_scope(node, query_text, parent_scope, bufnr, connection)
    return  -- Don't recurse - _extract_select_scope handles children
  elseif node_type == "subquery" then
    -- Subquery node: Contains select + from as direct children (not wrapped in statement)
    ScopeTracker._extract_subquery_scope(node, query_text, parent_scope, bufnr, connection)
    return  -- Don't recurse - handler takes care of children
  elseif node_type:match("with_clause") or node_type == "cte_clause" then
    ScopeTracker._extract_ctes(node, query_text, parent_scope, bufnr, connection)
  elseif node_type == "cte" then
    -- Direct CTE node (in case it appears elsewhere)
    ScopeTracker._extract_single_cte(node, query_text, parent_scope, bufnr, connection)
  end

  -- Recurse to children
  for child in node:iter_children() do
    local child_type = child:type()

    -- Search ERROR nodes for statement/cte
    if child_type == "ERROR" then
      debug_log("[SCOPE] Found ERROR node in _build_scope_tree_recursive (recursion), searching inside")

      -- First, look for properly wrapped statements
      local found_nodes = ScopeTracker._find_nodes_recursive(child, {"statement", "cte"}, {})
      for _, found_node in ipairs(found_nodes) do
        debug_log(string.format("[SCOPE] Found %s inside ERROR node", found_node:type()))
        ScopeTracker._build_scope_tree_recursive(found_node, query_text, parent_scope, bufnr, connection)
      end

      -- If no statements found, look for bare select nodes (incomplete statements)
      if #found_nodes == 0 then
        local select_nodes = ScopeTracker._find_nodes_recursive(child, {"select"}, {})
        for _, select_node in ipairs(select_nodes) do
          debug_log("[SCOPE] Found bare select node in ERROR - creating scope from ERROR bounds")
          -- Create scope using ERROR node bounds (since select bounds are incomplete)
          ScopeTracker._extract_error_select_scope(child, select_node, query_text, parent_scope, bufnr, connection)
        end
      end

      goto continue
    end

    ScopeTracker._build_scope_tree_recursive(child, query_text, parent_scope, bufnr, connection)

    ::continue::
  end
end

---Find SELECT statement within a CTE definition
---@param cte_node table Tree-sitter CTE node
---@param query_text string Original query text
---@return string? select_statement The SELECT statement text or nil
local function find_cte_select_statement(cte_node, query_text)
  -- Walk CTE children to find the SELECT part
  -- CTE structure: WITH name [(cols)] AS (select_statement)
  -- Look for: select, from, subquery nodes

  for child in cte_node:iter_children() do
    local child_type = child:type()

    -- Search ERROR nodes for select/subquery/statement
    if child_type == "ERROR" then
      debug_log("[SCOPE] Found ERROR node in find_cte_select_statement, searching inside")
      local found_nodes = ScopeTracker._find_nodes_recursive(child, {"select", "subquery", "statement"}, {})
      for _, found_node in ipairs(found_nodes) do
        debug_log(string.format("[SCOPE] Found %s inside ERROR node", found_node:type()))
        local select_text = vim.treesitter.get_node_text(found_node, query_text)
        select_text = select_text:gsub("^%s*%(", ""):gsub("%)%s*$", "")
        return select_text
      end
      goto continue
    end

    -- Look for subquery or statement containing SELECT
    if child_type == "subquery" or child_type == "statement" or child_type:match("select") then
      -- Extract text for this node
      local select_text = vim.treesitter.get_node_text(child, query_text)
      -- Remove surrounding parentheses if present
      select_text = select_text:gsub("^%s*%(", ""):gsub("%)%s*$", "")
      return select_text
    end

    ::continue::
  end

  return nil
end

---Find standalone asterisk (not in functions like COUNT(*))
---@param line string Line of text
---@return number? col Column position (0-indexed) or nil
local function find_standalone_asterisk(line)
  local paren_depth = 0

  for i = 1, #line do
    local char = line:sub(i, i)

    if char == '(' then
      paren_depth = paren_depth + 1
    elseif char == ')' then
      paren_depth = paren_depth - 1
    elseif char == '*' and paren_depth == 0 then
      -- Found standalone asterisk
      return i - 1  -- 0-indexed
    end
  end

  return nil
end

---Find position of asterisk in SELECT statement
---@param select_statement string The SELECT statement text
---@return number? line Line number (1-indexed)
---@return number? col Column number (0-indexed)
local function find_asterisk_position(select_statement)
  local lines = vim.split(select_statement, "\n")

  for line_idx, line in ipairs(lines) do
    -- Look for * in SELECT clause (not in functions like COUNT(*))
    -- Simple heuristic: Find * that's not inside parentheses
    local col = find_standalone_asterisk(line)
    if col then
      return line_idx, col
    end
  end

  return nil, nil
end

---Extract column name from column expression (handle AS alias)
---@param col_expr string Column expression
---@return string? name Column name or alias
local function extract_column_name(col_expr)
  col_expr = vim.trim(col_expr)

  -- Check for AS alias
  local alias = col_expr:match("%s+AS%s+([%w_]+)")
  if alias then
    return alias
  end

  -- Extract identifier (last part of dotted name)
  local identifier = col_expr:match("([%w_]+)%s*$")
  return identifier
end

---Parse column list from CTE SELECT statement (fallback for explicit columns)
---@param select_statement string The SELECT statement
---@return string[] columns Array of column names
local function parse_cte_column_list(select_statement)
  -- Extract SELECT clause (between SELECT and FROM)
  local select_clause = select_statement:match("SELECT%s+(.-)%s+FROM")
  if not select_clause then
    return {}
  end

  -- Split by comma (handle nested functions)
  local columns = {}
  local current_col = ""
  local paren_depth = 0

  for i = 1, #select_clause do
    local char = select_clause:sub(i, i)

    if char == '(' then
      paren_depth = paren_depth + 1
      current_col = current_col .. char
    elseif char == ')' then
      paren_depth = paren_depth - 1
      current_col = current_col .. char
    elseif char == ',' and paren_depth == 0 then
      -- End of column
      local col_name = extract_column_name(current_col)
      if col_name then
        table.insert(columns, col_name)
      end
      current_col = ""
    else
      current_col = current_col .. char
    end
  end

  -- Last column
  if current_col ~= "" then
    local col_name = extract_column_name(current_col)
    if col_name then
      table.insert(columns, col_name)
    end
  end

  return columns
end

---Expand asterisk in CTE SELECT statement to get column list
---@param select_statement string The CTE's SELECT statement
---@param bufnr number Buffer number
---@param connection table? Connection context
---@param query_text string Original full query text
---@param parent_scope QueryScope Parent scope (for CTEs referencing other CTEs)
---@return string[] columns Array of column names
local function expand_cte_asterisk(select_statement, bufnr, connection, query_text, parent_scope)
  -- Check if SELECT uses *
  if not select_statement:match("%*") then
    -- No asterisk, try to parse column list manually
    debug_log("CTE SELECT has no asterisk, parsing explicit columns")
    return parse_cte_column_list(select_statement)
  end

  -- Check if we have connection context (needed for expansion)
  if not connection or not connection.connection_string or not connection.database then
    debug_log("No connection context available for CTE asterisk expansion, falling back to empty")
    return {}
  end

  local Resolver = require('ssns.completion.metadata.resolver')

  -- Parse table references from SELECT statement
  -- Handle multiple patterns:
  -- 1. SELECT * FROM table
  -- 2. SELECT * FROM table1 JOIN table2 (multiple tables)
  -- 3. SELECT * FROM cte_name (where cte_name is in parent_scope)
  -- 4. SELECT e.*, ... (qualified asterisk with mixed columns)

  local col_names = {}

  -- Check if this is a mixed SELECT (e.*, other_col, ...)
  -- If SELECT has both * and other expressions, we need to handle both
  local select_clause = select_statement:match("SELECT%s+(.-)%s+FROM")
  if select_clause then
    -- Split by comma to find all expressions
    local expressions = {}
    local current_expr = ""
    local paren_depth = 0

    for i = 1, #select_clause do
      local char = select_clause:sub(i, i)
      if char == '(' then
        paren_depth = paren_depth + 1
        current_expr = current_expr .. char
      elseif char == ')' then
        paren_depth = paren_depth - 1
        current_expr = current_expr .. char
      elseif char == ',' and paren_depth == 0 then
        table.insert(expressions, vim.trim(current_expr))
        current_expr = ""
      else
        current_expr = current_expr .. char
      end
    end
    if current_expr ~= "" then
      table.insert(expressions, vim.trim(current_expr))
    end

    -- Process each expression
    for _, expr in ipairs(expressions) do
      if expr == "*" then
        -- Unqualified asterisk - expand all tables in FROM clause and JOINs
        -- Extract full FROM clause (including JOINs)
        local from_section = select_statement:match("FROM%s+(.-)%s*$") or select_statement:match("FROM%s+(.-)%s+WHERE")
        if from_section then
          -- Extract all table references (FROM table and JOIN table)
          local table_refs = {}

          -- Get main FROM table
          local main_table = from_section:match("^([%w_%.]+)")
          if main_table then
            table.insert(table_refs, main_table)
          end

          -- Get JOIN tables
          for join_table in from_section:gmatch("JOIN%s+([%w_%.]+)") do
            table.insert(table_refs, join_table)
          end

          -- Expand columns from all tables
          for _, table_ref in ipairs(table_refs) do
            -- Check if it's a CTE from parent scope
            if parent_scope.ctes[table_ref:lower()] then
              local cte_info = parent_scope.ctes[table_ref:lower()]
              for _, col in ipairs(cte_info.columns) do
                table.insert(col_names, col)
              end
            else
              -- It's a real table, resolve it
              local success, table_obj = pcall(function()
                return Resolver.resolve_table(table_ref, connection, bufnr, nil)
              end)
              if success and table_obj then
                local success, columns = pcall(function()
                  return Resolver.get_columns(table_obj, connection)
                end)
                if success and columns then
                  for _, col in ipairs(columns) do
                    table.insert(col_names, col.name)
                  end
                end
              end
            end
          end
        end
      elseif expr:match("^%w+%.%*$") then
        -- Qualified asterisk (e.*, d.*)
        local table_alias = expr:match("^(%w+)%.")
        if table_alias then
          -- Find the table/CTE this alias refers to
          -- For now, just get from first table (simplified)
          local from_clause = select_statement:match("FROM%s+(.-)%s*$") or select_statement:match("FROM%s+(.-)%s+WHERE") or select_statement:match("FROM%s+(.-)%s+JOIN")
          if from_clause then
            local table_ref = from_clause:match("^([%w_%.]+)")
            if table_ref then
              if parent_scope.ctes[table_ref:lower()] then
                local cte_info = parent_scope.ctes[table_ref:lower()]
                for _, col in ipairs(cte_info.columns) do
                  table.insert(col_names, col)
                end
              else
                local success, table_obj = pcall(function()
                  return Resolver.resolve_table(table_ref, connection, bufnr, nil)
                end)
                if success and table_obj then
                  local success, columns = pcall(function()
                    return Resolver.get_columns(table_obj, connection)
                  end)
                  if success and columns then
                    for _, col in ipairs(columns) do
                      table.insert(col_names, col.name)
                    end
                  end
                end
              end
            end
          end
        end
      else
        -- Regular column expression (might have AS alias)
        local col_name = extract_column_name(expr)
        if col_name then
          table.insert(col_names, col_name)
        end
      end
    end

    debug_log(string.format("Expanded CTE with mixed expressions to %d columns", #col_names))
    return col_names
  end

  debug_log("Could not parse SELECT clause in CTE")
  return {}
end

---Extract a single CTE node
---@param cte_node table Tree-sitter CTE node
---@param query_text string Original query text
---@param scope QueryScope Scope to add CTE to
---@param bufnr number? Buffer number
---@param connection table? Connection context
function ScopeTracker._extract_single_cte(cte_node, query_text, scope, bufnr, connection)
  local child_type = cte_node:type()

  if child_type ~= "cte" and child_type ~= "common_table_expression" then
    return
  end

  -- Extract CTE name and explicit column list
  -- AST structure: cte -> identifier (name) -> ( -> identifier (col1) -> , -> identifier (col2) -> ) -> keyword_as -> ...
  local cte_name = nil
  local cte_columns = {}
  local start_row, start_col = cte_node:range()
  local found_as = false

  for cte_child in cte_node:iter_children() do
    local cte_child_type = cte_child:type()

    -- Search ERROR nodes for identifier/column_list
    if cte_child_type == "ERROR" then
      debug_log("[SCOPE] Found ERROR node in _extract_single_cte, searching inside")
      local found_nodes = ScopeTracker._find_nodes_recursive(cte_child, {"identifier", "column_list"}, {})
      for _, found_node in ipairs(found_nodes) do
        local found_type = found_node:type()
        debug_log(string.format("[SCOPE] Found %s inside ERROR node", found_type))

        if found_type == "identifier" and not cte_name then
          cte_name = vim.treesitter.get_node_text(found_node, query_text)
          cte_name = ScopeTracker._clean_identifier(cte_name)
        elseif found_type == "identifier" and cte_name and not found_as then
          local col_name = vim.treesitter.get_node_text(found_node, query_text)
          table.insert(cte_columns, ScopeTracker._clean_identifier(col_name))
        elseif found_type == "column_list" then
          for col_child in found_node:iter_children() do
            if col_child:type() == "identifier" then
              local col_name = vim.treesitter.get_node_text(col_child, query_text)
              table.insert(cte_columns, ScopeTracker._clean_identifier(col_name))
            end
          end
        end
      end
      goto continue
    end

    if cte_child_type == "identifier" and not cte_name then
      -- First identifier is the CTE name
      cte_name = vim.treesitter.get_node_text(cte_child, query_text)
      cte_name = ScopeTracker._clean_identifier(cte_name)
    elseif cte_child_type == "identifier" and cte_name and not found_as then
      -- Subsequent identifiers before AS are column names
      local col_name = vim.treesitter.get_node_text(cte_child, query_text)
      table.insert(cte_columns, ScopeTracker._clean_identifier(col_name))
    elseif cte_child_type == "keyword_as" then
      -- Stop collecting columns after AS keyword
      found_as = true
    elseif cte_child_type == "column_list" then
      -- Some parsers might wrap columns in column_list node
      for col_child in cte_child:iter_children() do
        local col_child_type = col_child:type()

        if col_child_type == "identifier" then
          local col_name = vim.treesitter.get_node_text(col_child, query_text)
          table.insert(cte_columns, ScopeTracker._clean_identifier(col_name))
        end
      end
    end

    ::continue::
  end

  -- Check if CTE definition uses SELECT * (when no explicit column list)
  if #cte_columns == 0 and cte_name then
    -- No explicit column list, try to infer from SELECT statement
    debug_log(string.format("CTE '%s' has no explicit column list, attempting to infer from SELECT", cte_name))

    local cte_select = find_cte_select_statement(cte_node, query_text)
    if cte_select then
      debug_log(string.format("Found CTE SELECT statement (length: %d)", #cte_select))

      -- Try to expand asterisk or parse explicit columns
      local success, expanded_cols = pcall(function()
        return expand_cte_asterisk(cte_select, bufnr, connection, query_text, scope)
      end)

      if success and expanded_cols and #expanded_cols > 0 then
        cte_columns = expanded_cols
        debug_log(string.format("Successfully inferred %d columns for CTE '%s'", #cte_columns, cte_name))
      else
        debug_log(string.format("Could not infer columns for CTE '%s': %s", cte_name, tostring(expanded_cols)))
      end
    else
      debug_log(string.format("Could not find SELECT statement for CTE '%s'", cte_name))
    end
  end

  if cte_name then
    scope.ctes[cte_name:lower()] = {
      name = cte_name,
      columns = cte_columns,
      start_pos = { start_row + 1, start_col + 1 },  -- Convert to 1-indexed
    }
    debug_log(string.format("Registered CTE '%s' with %d columns", cte_name, #cte_columns))
  end
end

---Extract CTEs from WITH clause (wrapper that processes children)
---@param node table Tree-sitter node (with_clause)
---@param query_text string Original query text
---@param scope QueryScope Scope to add CTEs to
---@param bufnr number Buffer number
---@param connection table? Optional connection context
function ScopeTracker._extract_ctes(node, query_text, scope, bufnr, connection)
  -- Pattern: WITH cte_name [(columns)] AS (select_statement)
  -- CTEs are visible to all queries after their definition

  for child in node:iter_children() do
    local child_type = child:type()

    -- Search ERROR nodes for cte/common_table_expression
    if child_type == "ERROR" then
      debug_log("[SCOPE] Found ERROR node in _extract_ctes, searching inside")
      local found_nodes = ScopeTracker._find_nodes_recursive(child, {"cte", "common_table_expression"}, {})
      for _, found_node in ipairs(found_nodes) do
        debug_log(string.format("[SCOPE] Found %s inside ERROR node", found_node:type()))
        ScopeTracker._extract_single_cte(found_node, query_text, scope, bufnr, connection)
      end
      goto continue
    end

    if child_type == "cte" or child_type == "common_table_expression" then
      ScopeTracker._extract_single_cte(child, query_text, scope, bufnr, connection)
    end

    ::continue::
  end
end

---Extract scope from a statement node (contains select + from as siblings)
---@param node table Tree-sitter node (statement)
---@param query_text string Original query text
---@param parent_scope QueryScope Parent scope to add child to
---@param bufnr number Buffer number
---@param connection table? Optional connection context
function ScopeTracker._extract_select_scope(node, query_text, parent_scope, bufnr, connection)
  local start_row, start_col, end_row, end_col = node:range()

  debug_log(string.format("_extract_select_scope: Creating scope for statement at lines %d-%d",
    start_row + 1, end_row + 1))

  -- Check if this statement contains a set_operation (UNION, INTERSECT, EXCEPT)
  -- If so, extract each SELECT as a separate scope instead of one statement scope
  for child in node:iter_children() do
    local child_type = child:type()

    -- Search ERROR nodes for set_operation
    if child_type == "ERROR" then
      debug_log("[SCOPE] Found ERROR node in _extract_select_scope (set_operation check), searching inside")
      local found_nodes = ScopeTracker._find_nodes_recursive(child, {"set_operation"}, {})
      for _, found_node in ipairs(found_nodes) do
        debug_log("[SCOPE] Found set_operation inside ERROR node")
        ScopeTracker._extract_set_operation_scopes(found_node, query_text, parent_scope, bufnr, connection)
        return
      end
      goto continue
    end

    if child_type == "set_operation" then
      debug_log("Found set_operation (UNION/INTERSECT/EXCEPT), extracting each SELECT separately")
      ScopeTracker._extract_set_operation_scopes(child, query_text, parent_scope, bufnr, connection)
      return  -- Don't create a single scope for the whole statement
    end

    ::continue::
  end

  -- Determine scope type
  local scope_type = "main"
  local parent = node:parent()

  if parent then
    local parent_type = parent:type()
    if parent_type:match("subquery") or parent_type:match("derived") or parent_type:match("parenthesized") then
      scope_type = "subquery"
    elseif parent_type:match("cte") or parent_type:match("with_clause") then
      scope_type = "cte"
    end
  end

  debug_log(string.format("Scope type: %s", scope_type))

  -- Create scope for this statement
  -- Convert tree-sitter positions (0-indexed) to Neovim positions (1-indexed)
  -- start_col: add +1 to convert 0-indexed to 1-indexed
  -- end_col: keep as-is (tree-sitter's exclusive 0-indexed = inclusive 1-indexed)
  local select_scope = {
    type = scope_type,
    start_pos = {start_row + 1, start_col + 1},
    end_pos = {end_row + 1, end_col},
    aliases = {},
    ctes = {},
    parent = parent_scope,
    children = {},
    temp_tables = {},
  }

  -- Extend scope bounds to include following ERROR siblings that contain SQL clause keywords
  -- This handles multi-line queries where WHERE/GROUP/ORDER/HAVING are on separate lines
  local sibling = node:next_sibling()
  while sibling do
    local sibling_type = sibling:type()
    if sibling_type == "ERROR" then
      local error_text = vim.treesitter.get_node_text(sibling, query_text)
      local error_text_lower = error_text:lower()
      -- Check if ERROR contains SQL clause keywords that belong to this statement
      if error_text_lower:match("^%s*where") or
         error_text_lower:match("^%s*group") or
         error_text_lower:match("^%s*order") or
         error_text_lower:match("^%s*having") or
         error_text_lower:match("^%s*limit") then
        local _, _, sib_end_row, sib_end_col = sibling:range()
        select_scope.end_pos = {sib_end_row + 1, sib_end_col}
        debug_log(string.format("[SCOPE] Extended scope to include ERROR sibling (WHERE/GROUP/ORDER/HAVING): end={%d,%d}",
          select_scope.end_pos[1], select_scope.end_pos[2]))
      else
        break  -- Stop if ERROR doesn't contain expected clause keywords
      end
    elseif sibling_type:match("^keyword_") then
      -- Keywords like keyword_where might be siblings too
      local _, _, sib_end_row, sib_end_col = sibling:range()
      select_scope.end_pos = {sib_end_row + 1, sib_end_col}
      debug_log(string.format("[SCOPE] Extended scope to include keyword sibling: end={%d,%d}",
        select_scope.end_pos[1], select_scope.end_pos[2]))
    else
      break  -- Stop at first non-ERROR, non-keyword sibling
    end
    sibling = sibling:next_sibling()
  end

  debug_log(string.format("Created scope: start={%d,%d}, end={%d,%d}",
    select_scope.start_pos[1], select_scope.start_pos[2],
    select_scope.end_pos[1], select_scope.end_pos[2]))

  -- Add to parent
  table.insert(parent_scope.children, select_scope)

  -- Extract aliases from the statement's children
  -- In real AST: statement has "select" and "from" as SIBLING children
  ScopeTracker._extract_aliases_from_statement(node, query_text, select_scope, bufnr, connection)

  debug_log(string.format("Extracted aliases: %s", vim.inspect(select_scope.aliases)))
  debug_log(string.format("Parent scope now has %d children", #parent_scope.children))

  -- Recurse into nested statements (e.g., subqueries)
  for child in node:iter_children() do
    local child_type = child:type()

    -- Search ERROR nodes for statement/subquery
    if child_type == "ERROR" then
      debug_log("[SCOPE] Found ERROR node in _extract_select_scope (recursion), searching inside")
      local found_nodes = ScopeTracker._find_nodes_recursive(child, {"statement", "subquery"}, {})
      for _, found_node in ipairs(found_nodes) do
        debug_log(string.format("[SCOPE] Found %s inside ERROR node", found_node:type()))
        ScopeTracker._build_scope_tree_recursive(found_node, query_text, select_scope, bufnr, connection)
      end
      goto continue
    end

    ScopeTracker._build_scope_tree_recursive(child, query_text, select_scope, bufnr, connection)

    ::continue::
  end
end

---Extract scope for a SELECT statement inside an ERROR node
---Since tree-sitter misparsed it, use ERROR bounds and regex for tables
---@param error_node table Tree-sitter ERROR node
---@param select_node table Tree-sitter select node inside the ERROR
---@param query_text string Original query text
---@param parent_scope QueryScope Parent scope to add children to
---@param bufnr number Buffer number
---@param connection table? Optional connection context
function ScopeTracker._extract_error_select_scope(error_node, select_node, query_text, parent_scope, bufnr, connection)
  local start_row, start_col, end_row, end_col = error_node:range()

  debug_log(string.format("_extract_error_select_scope: Creating scope from ERROR at lines %d-%d",
    start_row + 1, end_row + 1))

  -- Create scope using ERROR node bounds
  local select_scope = {
    type = "main",
    start_pos = {start_row + 1, start_col + 1},
    end_pos = {end_row + 1, end_col},
    aliases = {},
    ctes = {},
    parent = parent_scope,
    children = {},
    temp_tables = {},
  }

  debug_log(string.format("Created ERROR scope: start={%d,%d}, end={%d,%d}",
    select_scope.start_pos[1], select_scope.start_pos[2],
    select_scope.end_pos[1], select_scope.end_pos[2]))

  -- Add to parent
  table.insert(parent_scope.children, select_scope)

  -- Extract tables using regex on ERROR node text (tree-sitter misparsed it)
  local error_text = vim.treesitter.get_node_text(error_node, query_text)
  ScopeTracker._extract_aliases_regex_fallback(error_text, select_scope)

  debug_log(string.format("Extracted aliases from ERROR: %s", vim.inspect(select_scope.aliases)))
end

---Extract scopes from a set_operation node (UNION, INTERSECT, EXCEPT)
---Each SELECT in the set operation gets its own scope
---@param node table Tree-sitter node (set_operation)
---@param query_text string Original query text
---@param parent_scope QueryScope Parent scope to add children to
---@param bufnr number Buffer number
---@param connection table? Optional connection context
function ScopeTracker._extract_set_operation_scopes(node, query_text, parent_scope, bufnr, connection)
  debug_log("_extract_set_operation_scopes: Processing UNION/INTERSECT/EXCEPT")

  -- set_operation contains:
  --   select (first)
  --   from (first)
  --   keyword_union/keyword_intersect/keyword_except
  --   select (second)
  --   from (second)
  --   ... (can be more)

  -- We need to group select + from pairs and create a scope for each
  local current_select = nil
  local current_from = nil

  for child in node:iter_children() do
    local child_type = child:type()

    -- Search ERROR nodes for select/from
    if child_type == "ERROR" then
      debug_log("[SCOPE] Found ERROR node in _extract_set_operation_scopes, searching inside")
      local found_nodes = ScopeTracker._find_nodes_recursive(child, {"select", "from"}, {})
      for _, found_node in ipairs(found_nodes) do
        local found_type = found_node:type()
        debug_log(string.format("[SCOPE] Found %s inside ERROR node", found_type))

        if found_type == "select" then
          current_select = found_node
        elseif found_type == "from" then
          current_from = found_node
        end
      end
      goto continue
    end

    if child_type == "select" then
      -- Save the current SELECT
      current_select = child
    elseif child_type == "from" then
      -- Match this FROM with the current SELECT
      current_from = child

      -- Create a scope for this SELECT + FROM pair
      if current_select then
        local start_row, start_col = current_select:range()
        local _, _, end_row, end_col = current_from:range()

        -- Convert tree-sitter positions to 1-indexed
        local select_scope = {
          type = "main",  -- Each part of UNION is a main-level scope
          start_pos = {start_row + 1, start_col + 1},
          end_pos = {end_row + 1, end_col},
          aliases = {},
          ctes = {},
          parent = parent_scope,
          children = {},
          temp_tables = {},
        }

        debug_log(string.format("Created UNION/set scope: start={%d,%d}, end={%d,%d}",
          select_scope.start_pos[1], select_scope.start_pos[2],
          select_scope.end_pos[1], select_scope.end_pos[2]))

        -- Add to parent
        table.insert(parent_scope.children, select_scope)

        -- Extract aliases from the FROM clause
        ScopeTracker._extract_from_aliases(current_from, query_text, select_scope, bufnr, connection)

        -- Process nested subqueries in the SELECT
        for select_child in current_select:iter_children() do
          local select_child_type = select_child:type()

          -- Search ERROR nodes for statement/subquery
          if select_child_type == "ERROR" then
            debug_log("[SCOPE] Found ERROR node in _extract_set_operation_scopes (SELECT recursion), searching inside")
            local inner_found = ScopeTracker._find_nodes_recursive(select_child, {"statement", "subquery"}, {})
            for _, inner_node in ipairs(inner_found) do
              debug_log(string.format("[SCOPE] Found %s inside ERROR node", inner_node:type()))
              ScopeTracker._build_scope_tree_recursive(inner_node, query_text, select_scope, bufnr, connection)
            end
            goto continue_inner
          end

          ScopeTracker._build_scope_tree_recursive(select_child, query_text, select_scope, bufnr, connection)

          ::continue_inner::
        end

        debug_log(string.format("Extracted set_operation scope aliases: %s", vim.inspect(select_scope.aliases)))

        -- Reset for next pair
        current_select = nil
        current_from = nil
      end
    end

    ::continue::
  end
end

---Extract scope from a subquery node (contains select + from as direct children, not wrapped in statement)
---@param node table Tree-sitter node (subquery)
---@param query_text string Original query text
---@param parent_scope QueryScope Parent scope to add child to
---@param bufnr number Buffer number
---@param connection table? Optional connection context
function ScopeTracker._extract_subquery_scope(node, query_text, parent_scope, bufnr, connection)
  local start_row, start_col, end_row, end_col = node:range()

  debug_log(string.format("_extract_subquery_scope: Creating scope for subquery at lines %d-%d",
    start_row + 1, end_row + 1))

  -- Subqueries are always "subquery" type
  -- Convert tree-sitter positions to 1-indexed
  local subquery_scope = {
    type = "subquery",
    start_pos = {start_row + 1, start_col + 1},
    end_pos = {end_row + 1, end_col},
    aliases = {},
    ctes = {},
    parent = parent_scope,
    children = {},
    temp_tables = {},
  }

  debug_log(string.format("Created subquery scope: start={%d,%d}, end={%d,%d}",
    subquery_scope.start_pos[1], subquery_scope.start_pos[2],
    subquery_scope.end_pos[1], subquery_scope.end_pos[2]))

  -- Add to parent
  table.insert(parent_scope.children, subquery_scope)

  -- Extract aliases from subquery's children
  -- Unlike statement nodes, subquery has select/from as DIRECT children
  for child in node:iter_children() do
    local child_type = child:type()

    -- Search ERROR nodes for from/join/select
    if child_type == "ERROR" then
      debug_log("[SCOPE] Found ERROR node in _extract_subquery_scope, searching inside")
      local found_nodes = ScopeTracker._find_nodes_recursive(child, {"from", "join", "select"}, {})
      for _, found_node in ipairs(found_nodes) do
        local found_type = found_node:type()
        debug_log(string.format("[SCOPE] Found %s inside ERROR node", found_type))

        if found_type == "from" then
          ScopeTracker._extract_from_aliases(found_node, query_text, subquery_scope, bufnr, connection)
        elseif found_type:match("join") then
          ScopeTracker._extract_join_aliases(found_node, query_text, subquery_scope, bufnr, connection)
        elseif found_type == "select" then
          for select_child in found_node:iter_children() do
            ScopeTracker._build_scope_tree_recursive(select_child, query_text, subquery_scope, bufnr, connection)
          end
        end
      end
      goto continue
    end

    if child_type == "from" then
      debug_log("Found FROM in subquery")
      ScopeTracker._extract_from_aliases(child, query_text, subquery_scope, bufnr, connection)
    elseif child_type:match("join") then
      debug_log("Found JOIN in subquery")
      ScopeTracker._extract_join_aliases(child, query_text, subquery_scope, bufnr, connection)
    elseif child_type == "select" then
      -- Process nested subqueries within the SELECT
      for select_child in child:iter_children() do
        local select_child_type = select_child:type()

        -- Search ERROR nodes for statement/subquery
        if select_child_type == "ERROR" then
          debug_log("[SCOPE] Found ERROR node in _extract_subquery_scope (SELECT recursion), searching inside")
          local inner_found = ScopeTracker._find_nodes_recursive(select_child, {"statement", "subquery"}, {})
          for _, inner_node in ipairs(inner_found) do
            debug_log(string.format("[SCOPE] Found %s inside ERROR node", inner_node:type()))
            ScopeTracker._build_scope_tree_recursive(inner_node, query_text, subquery_scope, bufnr, connection)
          end
          goto continue_inner
        end

        ScopeTracker._build_scope_tree_recursive(select_child, query_text, subquery_scope, bufnr, connection)

        ::continue_inner::
      end
    end

    ::continue::
  end

  debug_log(string.format("Extracted subquery aliases: %s", vim.inspect(subquery_scope.aliases)))
  debug_log(string.format("Parent scope now has %d children", #parent_scope.children))
end

---Extract aliases from statement node (select + from are siblings)
---@param node table Tree-sitter node (statement)
---@param query_text string Original query text
---@param scope QueryScope Scope to add aliases to
---@param bufnr number Buffer number
---@param connection table? Optional connection context
function ScopeTracker._extract_aliases_from_statement(node, query_text, scope, bufnr, connection)
  -- Walk children to find FROM and JOIN clauses
  -- NOTE: In real AST, FROM is a SIBLING of SELECT, not a child of SELECT
  debug_log("[SCOPE] _extract_aliases_from_statement: iterating children of node type=" .. node:type())

  local child_count = 0
  for child in node:iter_children() do
    child_count = child_count + 1
    local child_type = child:type()
    debug_log(string.format("[SCOPE] _extract_aliases_from_statement: child #%d type=%s", child_count, child_type))

    -- Search ERROR nodes for from/join
    if child_type == "ERROR" then
      debug_log("[SCOPE] Found ERROR node in _extract_aliases_from_statement, searching inside for FROM/JOIN")
      local found_nodes = ScopeTracker._find_nodes_recursive(child, {"from", "join"}, {})
      for _, found_node in ipairs(found_nodes) do
        local found_type = found_node:type()
        debug_log(string.format("[SCOPE] Found %s inside ERROR node", found_type))

        if found_type == "from" then
          ScopeTracker._extract_from_aliases(found_node, query_text, scope, bufnr, connection)
        elseif found_type:match("join") then
          ScopeTracker._extract_join_aliases(found_node, query_text, scope, bufnr, connection)
        end
      end
      goto continue
    end

    if child_type == "select" then
      -- FROM is inside SELECT in tree-sitter SQL grammar
      debug_log("[SCOPE] Found select node, searching inside for FROM/JOIN")
      local found_nodes = ScopeTracker._find_nodes_recursive(child, {"from", "join"}, {})
      for _, found_node in ipairs(found_nodes) do
        local found_type = found_node:type()
        debug_log(string.format("[SCOPE] Found %s inside select node", found_type))

        if found_type == "from" then
          ScopeTracker._extract_from_aliases(found_node, query_text, scope, bufnr, connection)
        elseif found_type:match("join") then
          ScopeTracker._extract_join_aliases(found_node, query_text, scope, bufnr, connection)
        end
      end
      goto continue
    end

    if child_type == "from" then
      debug_log(string.format("Found FROM clause at %s", child_type))
      ScopeTracker._extract_from_aliases(child, query_text, scope, bufnr, connection)
    elseif child_type:match("join") then
      debug_log(string.format("Found JOIN clause at %s", child_type))
      ScopeTracker._extract_join_aliases(child, query_text, scope, bufnr, connection)
    end

    ::continue::
  end

  debug_log(string.format("[SCOPE] _extract_aliases_from_statement: finished, processed %d children", child_count))

  -- Regex fallback: If no aliases found but query contains FROM/JOIN keywords
  if vim.tbl_isempty(scope.aliases) then
    local query_lower = query_text:lower()
    if query_lower:match("%s+from%s+") or query_lower:match("%s+join%s+") then
      debug_log("[SCOPE] No aliases found via tree-sitter, falling back to regex")
      ScopeTracker._extract_aliases_regex_fallback(query_text, scope)
    end
  end
end

---Extract aliases from FROM clause (real AST structure)
---@param node table Tree-sitter node (from)
---@param query_text string Original query text
---@param scope QueryScope Scope to add aliases to
---@param bufnr number Buffer number
---@param connection table? Optional connection context
function ScopeTracker._extract_from_aliases(node, query_text, scope, bufnr, connection)
  -- Real AST structure:
  -- from
  --   ├─ relation "dbo.Employees e"  (main table)
  --   │   ├─ object_reference "dbo.Employees"
  --   │   └─ identifier "e"  (the alias)
  --   └─ join  (JOIN clause is a child of FROM!)
  --       └─ relation "dbo.Departments d"
  --           ├─ object_reference "dbo.Departments"
  --           └─ identifier "d"
  --
  -- For subqueries:
  -- from
  --   └─ relation
  --       ├─ subquery (contains select/from)
  --       └─ identifier "alias"  (SIBLING to subquery!)

  for child in node:iter_children() do
    local child_type = child:type()

    -- Search ERROR nodes for relation/join
    if child_type == "ERROR" then
      debug_log("[SCOPE] Found ERROR node in _extract_from_aliases, searching inside")
      local found_nodes = ScopeTracker._find_nodes_recursive(child, {"relation", "join"}, {})
      for _, found_node in ipairs(found_nodes) do
        local found_type = found_node:type()
        debug_log(string.format("[SCOPE] Found %s inside ERROR node", found_type))

        if found_type == "relation" then
          -- Process relation found in ERROR node
          local table_parts = {}
          local alias = nil
          local has_subquery = false

          for relation_child in found_node:iter_children() do
            local relation_child_type = relation_child:type()

            if relation_child_type == "object_reference" then
              local table_name = vim.treesitter.get_node_text(relation_child, query_text)
              table.insert(table_parts, table_name)
            elseif relation_child_type == "subquery" then
              has_subquery = true
              ScopeTracker._extract_subquery_scope(relation_child, query_text, scope, bufnr, connection)
            elseif relation_child_type == "identifier" then
              alias = vim.treesitter.get_node_text(relation_child, query_text)
            end
          end

          if #table_parts > 0 and alias then
            local full_table_name = table.concat(table_parts, ".")
            scope.aliases[alias:lower()] = full_table_name
            debug_log(string.format("Extracted alias from ERROR: %s -> %s", alias, full_table_name))
          elseif #table_parts > 0 then
            local full_table_name = table.concat(table_parts, ".")
            local table_name = full_table_name:match("%.([^%.]+)$") or full_table_name
            scope.aliases[table_name:lower()] = full_table_name
            debug_log(string.format("Extracted non-aliased table from ERROR: %s -> %s", table_name, full_table_name))
          end
        elseif found_type:match("join") then
          ScopeTracker._extract_join_aliases(found_node, query_text, scope, bufnr, connection)
        end
      end
      goto continue
    end

    if child_type == "relation" then
      -- Found a table reference (main FROM table)
      local table_parts = {}
      local alias = nil
      local has_subquery = false
      local encountered_select_error = false  -- Flag to detect multi-statement confusion

      -- Get children of relation: object_reference + optional identifier (alias)
      -- OR: subquery + identifier (alias as sibling)
      for relation_child in child:iter_children() do
        local relation_child_type = relation_child:type()

        -- Search ERROR nodes in relation for object_reference/identifier
        if relation_child_type == "ERROR" then
          -- Check if ERROR contains SELECT keyword (indicates multi-statement confusion)
          local error_text = vim.treesitter.get_node_text(relation_child, query_text)
          if error_text:lower():match("^%s*select") then
            debug_log("[SCOPE] ERROR node contains SELECT - multi-statement detected, stopping relation processing")
            encountered_select_error = true
            break  -- Stop processing this relation - what follows is a different statement
          end

          debug_log("[SCOPE] Found ERROR node in _extract_from_aliases (relation), searching inside")
          local inner_found = ScopeTracker._find_nodes_recursive(relation_child, {"object_reference", "identifier", "subquery"}, {})
          for _, inner_node in ipairs(inner_found) do
            local inner_type = inner_node:type()
            debug_log(string.format("[SCOPE] Found %s inside ERROR node", inner_type))

            if inner_type == "object_reference" then
              local table_name = vim.treesitter.get_node_text(inner_node, query_text)
              table.insert(table_parts, table_name)
            elseif inner_type == "subquery" then
              has_subquery = true
              ScopeTracker._extract_subquery_scope(inner_node, query_text, scope, bufnr, connection)
            elseif inner_type == "identifier" then
              alias = vim.treesitter.get_node_text(inner_node, query_text)
            end
          end
          goto continue_inner
        end

        if relation_child_type == "object_reference" then
          -- Extract table name (may be schema.table)
          local table_name = vim.treesitter.get_node_text(relation_child, query_text)
          table.insert(table_parts, table_name)
        elseif relation_child_type == "subquery" then
          -- Mark that this is a subquery reference
          has_subquery = true
          -- Process the subquery to create nested scope
          ScopeTracker._extract_subquery_scope(relation_child, query_text, scope, bufnr, connection)
        elseif relation_child_type == "identifier" then
          -- This is the alias (for table OR subquery)
          -- But skip if we've already found a table and encountered a SELECT error
          if not encountered_select_error then
            alias = vim.treesitter.get_node_text(relation_child, query_text)
          else
            debug_log(string.format("[SCOPE] Skipping identifier '%s' after SELECT error",
              vim.treesitter.get_node_text(relation_child, query_text)))
          end
        end

        ::continue_inner::
      end

      -- Only add alias if it's for a real table (not a subquery, which creates its own scope)
      if #table_parts > 0 and alias then
        -- Table with explicit alias
        local full_table_name = table.concat(table_parts, ".")
        scope.aliases[alias:lower()] = full_table_name
        debug_log(string.format("Extracted alias: %s -> %s", alias, full_table_name))
      elseif #table_parts > 0 then
        -- Table without alias - use table name as both key and value
        local full_table_name = table.concat(table_parts, ".")
        -- Extract just the table name (without schema) for the alias key
        local table_name = full_table_name:match("%.([^%.]+)$") or full_table_name
        scope.aliases[table_name:lower()] = full_table_name
        debug_log(string.format("Extracted non-aliased table: %s -> %s", table_name, full_table_name))
      elseif has_subquery and alias then
        debug_log(string.format("Found subquery alias: %s (subquery scope already created)", alias))
      end
    elseif child_type == "join" or child_type:match("join") then
      -- JOIN is a child of FROM, so extract its aliases here
      debug_log(string.format("Found JOIN as child of FROM: %s", child_type))
      ScopeTracker._extract_join_aliases(child, query_text, scope, bufnr, connection)
    end

    ::continue::
  end
end

---Extract aliases from JOIN clause (real AST structure)
---@param node table Tree-sitter node (join_clause or join variant)
---@param query_text string Original query text
---@param scope QueryScope Scope to add aliases to
---@param bufnr number Buffer number (currently unused but kept for consistency)
---@param connection table? Optional connection context (currently unused but kept for consistency)
function ScopeTracker._extract_join_aliases(node, query_text, scope, bufnr, connection)
  -- Real AST structure similar to FROM:
  -- join_clause
  --   └─ relation "dbo.TableName alias"
  --       ├─ object_reference "dbo.TableName"
  --       └─ identifier "alias"

  for child in node:iter_children() do
    local child_type = child:type()

    -- Search ERROR nodes for relation
    if child_type == "ERROR" then
      debug_log("[SCOPE] Found ERROR node in _extract_join_aliases, searching inside")
      local found_nodes = ScopeTracker._find_nodes_recursive(child, {"relation"}, {})
      for _, found_node in ipairs(found_nodes) do
        debug_log("[SCOPE] Found relation inside ERROR node")

        -- Process relation found in ERROR node
        local table_parts = {}
        local alias = nil

        for relation_child in found_node:iter_children() do
          local relation_child_type = relation_child:type()

          if relation_child_type == "object_reference" then
            local table_name = vim.treesitter.get_node_text(relation_child, query_text)
            table.insert(table_parts, table_name)
          elseif relation_child_type == "identifier" then
            alias = vim.treesitter.get_node_text(relation_child, query_text)
          end
        end

        if #table_parts > 0 and alias then
          local full_table_name = table.concat(table_parts, ".")
          scope.aliases[alias:lower()] = full_table_name
          debug_log(string.format("Extracted JOIN alias from ERROR: %s -> %s", alias, full_table_name))
        elseif #table_parts > 0 then
          local full_table_name = table.concat(table_parts, ".")
          local table_name = full_table_name:match("%.([^%.]+)$") or full_table_name
          scope.aliases[table_name:lower()] = full_table_name
          debug_log(string.format("Extracted non-aliased JOIN table from ERROR: %s -> %s", table_name, full_table_name))
        end
      end
      goto continue
    end

    if child_type == "relation" then
      -- Found a table reference in the JOIN
      local table_parts = {}
      local alias = nil

      -- Get children of relation: object_reference + optional identifier (alias)
      for relation_child in child:iter_children() do
        local relation_child_type = relation_child:type()

        -- Search ERROR nodes in relation for object_reference/identifier
        if relation_child_type == "ERROR" then
          debug_log("[SCOPE] Found ERROR node in _extract_join_aliases (relation), searching inside")
          local inner_found = ScopeTracker._find_nodes_recursive(relation_child, {"object_reference", "identifier"}, {})
          for _, inner_node in ipairs(inner_found) do
            local inner_type = inner_node:type()
            debug_log(string.format("[SCOPE] Found %s inside ERROR node", inner_type))

            if inner_type == "object_reference" then
              local table_name = vim.treesitter.get_node_text(inner_node, query_text)
              table.insert(table_parts, table_name)
            elseif inner_type == "identifier" then
              alias = vim.treesitter.get_node_text(inner_node, query_text)
            end
          end
          goto continue_inner
        end

        if relation_child_type == "object_reference" then
          -- Extract table name (may be schema.table)
          local table_name = vim.treesitter.get_node_text(relation_child, query_text)
          table.insert(table_parts, table_name)
        elseif relation_child_type == "identifier" then
          -- This is the alias
          alias = vim.treesitter.get_node_text(relation_child, query_text)
        end

        ::continue_inner::
      end

      if #table_parts > 0 and alias then
        -- JOIN table with explicit alias
        local full_table_name = table.concat(table_parts, ".")
        scope.aliases[alias:lower()] = full_table_name
        debug_log(string.format("Extracted JOIN alias: %s -> %s", alias, full_table_name))
      elseif #table_parts > 0 then
        -- JOIN table without alias - use table name as both key and value
        local full_table_name = table.concat(table_parts, ".")
        -- Extract just the table name (without schema) for the alias key
        local table_name = full_table_name:match("%.([^%.]+)$") or full_table_name
        scope.aliases[table_name:lower()] = full_table_name
        debug_log(string.format("Extracted non-aliased JOIN table: %s -> %s", table_name, full_table_name))
      end
    end

    ::continue::
  end
end

---Get scope at cursor position
---Returns the innermost scope containing the cursor
---@param scope_tree QueryScope Global scope tree
---@param cursor_pos table {row, col} Cursor position (1-indexed)
---@return QueryScope scope The innermost scope containing cursor
function ScopeTracker.get_scope_at_cursor(scope_tree, cursor_pos)
  debug_log(string.format("get_scope_at_cursor: cursor at {%d,%d}",
    cursor_pos[1], cursor_pos[2]))

  -- Recursively search scope tree
  local scope = ScopeTracker._find_innermost_scope(scope_tree, cursor_pos)

  if scope then
    debug_log(string.format("Found scope: type=%s, bounds={%d,%d} to {%d,%d}",
      scope.type,
      scope.start_pos[1], scope.start_pos[2],
      scope.end_pos[1], scope.end_pos[2]))
    debug_log("Scope aliases: " .. vim.inspect(scope.aliases))
  else
    debug_log("No scope found!")
  end

  return scope
end

---Helper: Find innermost scope containing cursor position
---@param scope QueryScope Current scope to search
---@param cursor_pos table {row, col} Cursor position (1-indexed)
---@return QueryScope scope Innermost scope or input scope if no children match
function ScopeTracker._find_innermost_scope(scope, cursor_pos)
  debug_log(string.format("_find_innermost_scope: checking scope type=%s, bounds={%d,%d} to {%d,%d}",
    scope.type,
    scope.start_pos[1], scope.start_pos[2],
    scope.end_pos[1], scope.end_pos[2]))

  -- Check if cursor is within this scope
  if not ScopeTracker._is_position_in_scope(cursor_pos, scope) then
    debug_log("Position NOT in this scope")
    return scope -- Return current scope (fallback)
  end

  debug_log("Position IS in this scope")

  -- Check children for more specific scope
  for i, child in ipairs(scope.children) do
    debug_log(string.format("Checking child %d/%d", i, #scope.children))
    if ScopeTracker._is_position_in_scope(cursor_pos, child) then
      -- Recurse into child
      debug_log("Found in child!")
      return ScopeTracker._find_innermost_scope(child, cursor_pos)
    end
  end

  -- No child contains cursor, return this scope
  debug_log("No children matched, returning this scope")
  return scope
end

---Get all table aliases available at cursor position
---Includes aliases from current scope and parent scopes
---@param scope_tree QueryScope Global scope tree
---@param cursor_pos table {row, col} Cursor position (1-indexed)
---@return table<string, string> aliases Alias -> table mapping
function ScopeTracker.get_available_aliases(scope_tree, cursor_pos)
  debug_log(string.format("get_available_aliases: cursor at {%d,%d}",
    cursor_pos[1], cursor_pos[2]))

  local scope = ScopeTracker.get_scope_at_cursor(scope_tree, cursor_pos)
  local aliases = {}

  -- Collect aliases from current scope and parent scopes
  local current = scope
  while current do
    debug_log(string.format("Collecting from scope type=%s", current.type))
    -- Add aliases from current scope (don't override more specific ones)
    for alias, table_name in pairs(current.aliases) do
      if not aliases[alias] then
        aliases[alias] = table_name
        debug_log(string.format("Added: %s -> %s", alias, table_name))
      else
        debug_log(string.format("Skipped (already exists): %s", alias))
      end
    end

    -- Move to parent scope
    current = current.parent
  end

  debug_log("Final aliases: " .. vim.inspect(aliases))
  return aliases
end

---Get all CTEs available at cursor position
---Returns CTEs defined in parent scopes (CTEs defined above current position)
---@param scope_tree QueryScope Global scope tree
---@param cursor_pos table {row, col} Cursor position (1-indexed)
---@return table<string, table> ctes CTE name -> CTE info
function ScopeTracker.get_available_ctes(scope_tree, cursor_pos)
  local scope = ScopeTracker.get_scope_at_cursor(scope_tree, cursor_pos)
  local ctes = {}

  -- Collect CTEs from current scope and parent scopes
  local current = scope
  while current do
    -- Add CTEs from current scope (don't override more specific ones)
    for cte_name, cte_info in pairs(current.ctes) do
      if not ctes[cte_name] then
        -- Only include CTEs defined before cursor position
        if cte_info.start_pos[1] < cursor_pos[1] or
           (cte_info.start_pos[1] == cursor_pos[1] and cte_info.start_pos[2] < cursor_pos[2]) then
          ctes[cte_name] = cte_info
        end
      end
    end

    -- Move to parent scope
    current = current.parent
  end

  return ctes
end

---Helper: Create fallback scope when Tree-sitter unavailable
---Uses regex-based alias parsing for compatibility
---@param query_text string SQL query
---@return QueryScope global_scope Simple flat scope with regex-parsed aliases
function ScopeTracker._create_fallback_scope(query_text)
  local Context = require('ssns.completion.context')

  -- Use existing regex-based alias parsing
  local aliases = Context.parse_aliases(query_text)

  return {
    type = "global",
    start_pos = { 1, 1 },  -- 1-indexed (Neovim convention)
    end_pos = { 9999, 999999 },
    aliases = aliases,
    ctes = {},
    parent = nil,
    children = {},
    temp_tables = {}, -- Placeholder for Phase 10.5
  }
end

---Helper: Check if position is within scope bounds
---@param pos table {row, col} Position to check (1-indexed)
---@param scope QueryScope Scope with start_pos and end_pos
---@return boolean is_within True if position is within scope
function ScopeTracker._is_position_in_scope(pos, scope)
  local row, col = pos[1], pos[2]

  -- Check row bounds
  if row < scope.start_pos[1] or row > scope.end_pos[1] then
    return false
  end

  -- If same row as start, check column
  if row == scope.start_pos[1] and col < scope.start_pos[2] then
    return false
  end

  -- If same row as end, check column with tolerance
  -- Allow cursor to be past end position (for incomplete queries where user is typing)
  -- Tolerance of 100 chars accounts for typing after keywords like WHERE, JOIN, etc.
  local END_TOLERANCE = 100
  if row == scope.end_pos[1] and col > scope.end_pos[2] + END_TOLERANCE then
    return false
  end

  return true
end

---Helper: Strip brackets/quotes from identifier
---@param identifier string Identifier with possible brackets/quotes
---@return string clean Cleaned identifier
function ScopeTracker._clean_identifier(identifier)
  if not identifier then
    return ""
  end

  -- Remove: [brackets], "quotes", `backticks`
  local cleaned = identifier
  cleaned = cleaned:gsub("^%[(.-)%]$", "%1")
  cleaned = cleaned:gsub('^"(.-)"$', "%1")
  cleaned = cleaned:gsub("^`(.-)`$", "%1")

  return cleaned
end

---Regex fallback for extracting aliases when tree-sitter fails
---@param query_text string SQL query text
---@param scope QueryScope Scope to add aliases to
function ScopeTracker._extract_aliases_regex_fallback(query_text, scope)
  local query_lower = query_text:lower()

  -- SQL keywords to skip (avoid treating keywords as aliases)
  local sql_keywords = {
    where = true, join = true, inner = true, left = true, right = true,
    outer = true, cross = true, on = true, ["and"] = true, ["or"] = true,
    group = true, order = true, having = true, limit = true, offset = true,
    union = true, except = true, intersect = true, as = true,
  }

  -- Pattern 1: FROM [schema.]table AS alias
  for schema_table, alias in query_lower:gmatch("from%s+([%w%[%]%.]+)%s+as%s+(%w+)") do
    if not sql_keywords[alias] then
      debug_log(string.format("[SCOPE] Regex fallback found: %s -> %s (FROM with AS)", alias, schema_table))
      scope.aliases[alias] = schema_table
    end
  end

  -- Pattern 2: FROM [schema.]table alias (without AS)
  for schema_table, alias in query_lower:gmatch("from%s+([%w%[%]%.]+)%s+(%w+)") do
    if not sql_keywords[alias] and not scope.aliases[alias] then
      debug_log(string.format("[SCOPE] Regex fallback found: %s -> %s (FROM without AS)", alias, schema_table))
      scope.aliases[alias] = schema_table
    end
  end

  -- Pattern 3: JOIN [schema.]table AS alias
  for schema_table, alias in query_lower:gmatch("join%s+([%w%[%]%.]+)%s+as%s+(%w+)") do
    if not sql_keywords[alias] then
      debug_log(string.format("[SCOPE] Regex fallback found JOIN: %s -> %s (with AS)", alias, schema_table))
      scope.aliases[alias] = schema_table
    end
  end

  -- Pattern 4: JOIN [schema.]table alias (without AS)
  for schema_table, alias in query_lower:gmatch("join%s+([%w%[%]%.]+)%s+(%w+)") do
    if not sql_keywords[alias] and not scope.aliases[alias] then
      debug_log(string.format("[SCOPE] Regex fallback found JOIN: %s -> %s (without AS)", alias, schema_table))
      scope.aliases[alias] = schema_table
    end
  end

  -- Pattern 5: FROM [schema.]table (no alias - followed by JOIN/WHERE/GROUP/ORDER/ON or end)
  -- This handles non-aliased FROM tables like: FROM dbo.EMPLOYEES JOIN ...
  for schema_table in query_lower:gmatch("from%s+([%w%[%]%.]+)%s+[jwgoh]") do
    local table_name = schema_table:match("%.([^%.]+)$") or schema_table
    if not scope.aliases[table_name] then
      debug_log(string.format("[SCOPE] Regex fallback found non-aliased FROM: %s -> %s", table_name, schema_table))
      scope.aliases[table_name] = schema_table
    end
  end

  -- Pattern 6: JOIN [schema.]table ON (no alias)
  -- This handles non-aliased JOIN tables like: JOIN dbo.DEPARTMENTS ON ...
  for schema_table in query_lower:gmatch("join%s+([%w%[%]%.]+)%s+on") do
    local table_name = schema_table:match("%.([^%.]+)$") or schema_table
    if not scope.aliases[table_name] then
      debug_log(string.format("[SCOPE] Regex fallback found non-aliased JOIN: %s -> %s", table_name, schema_table))
      scope.aliases[table_name] = schema_table
    end
  end

  -- Pattern 7: FROM [schema.]table at end of text (no trailing keyword)
  -- This handles incomplete queries like: SELECT  FROM dbo.EMPLOYEES
  for schema_table in query_lower:gmatch("from%s+([%w%[%]%.]+)%s*$") do
    local table_name = schema_table:match("%.([^%.]+)$") or schema_table
    if not scope.aliases[table_name] then
      debug_log(string.format("[SCOPE] Regex fallback found non-aliased FROM at end: %s -> %s", table_name, schema_table))
      scope.aliases[table_name] = schema_table
    end
  end

  -- Pattern 8: FROM [schema.]table followed by newline or semicolon
  -- This handles multi-statement queries like: SELECT * FROM dbo.EMPLOYEES\nSELECT...
  for schema_table in query_lower:gmatch("from%s+([%w%[%]%.]+)%s*[\n;]") do
    local table_name = schema_table:match("%.([^%.]+)$") or schema_table
    if not scope.aliases[table_name] then
      debug_log(string.format("[SCOPE] Regex fallback found non-aliased FROM before newline/;: %s -> %s", table_name, schema_table))
      scope.aliases[table_name] = schema_table
    end
  end

  debug_log(string.format("[SCOPE] Regex fallback extracted %d aliases", vim.tbl_count(scope.aliases)))
end

return ScopeTracker
