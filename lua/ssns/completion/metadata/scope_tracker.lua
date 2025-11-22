---Scope tracker for SQL query parsing
---Handles nested queries, subqueries, CTEs, and derived tables for accurate alias/table resolution
---Uses Tree-sitter for robust parsing with regex fallback
---@class ScopeTracker
local ScopeTracker = {}

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
---@return QueryScope global_scope Root scope containing all nested scopes
function ScopeTracker.build_scope_tree(query_text, bufnr)
  -- Step 1: Try Tree-sitter based parsing
  local Treesitter = require('ssns.completion.metadata.treesitter')
  local root = Treesitter.parse_sql(query_text)

  if not root then
    -- Fallback: Create simple global scope with flat aliases
    return ScopeTracker._create_fallback_scope(query_text)
  end

  -- Step 2: Create global scope
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local global_scope = {
    type = "global",
    start_pos = { 1, 0 },
    end_pos = { line_count, 999999 },
    aliases = {},
    ctes = {},
    parent = nil,
    children = {},
    temp_tables = {}, -- Placeholder for Phase 10.5
  }

  -- Step 3: Walk AST to find scopes
  ScopeTracker._build_scope_tree_recursive(root, query_text, global_scope)

  return global_scope
end

---Recursively build scope tree by walking AST
---@param node table Tree-sitter node
---@param query_text string Original query text
---@param parent_scope QueryScope Parent scope to attach children to
function ScopeTracker._build_scope_tree_recursive(node, query_text, parent_scope)
  if not node then
    return
  end

  local node_type = node:type()

  -- Process current node based on type
  if node_type == "with_clause" or node_type == "cte_clause" then
    -- WITH clause: Extract CTEs
    ScopeTracker._extract_ctes(node, query_text, parent_scope)
  elseif node_type:match("select") then
    -- SELECT statement: Could be main query or subquery
    ScopeTracker._extract_select_scope(node, query_text, parent_scope)
  elseif node_type:match("from") then
    -- FROM clause: Extract table references and aliases
    ScopeTracker._extract_from_aliases(node, query_text, parent_scope)
  elseif node_type:match("join") then
    -- JOIN clause: Extract table references and aliases
    ScopeTracker._extract_join_aliases(node, query_text, parent_scope)
  end

  -- Recurse to children
  for child in node:iter_children() do
    ScopeTracker._build_scope_tree_recursive(child, query_text, parent_scope)
  end
end

---Extract CTEs from WITH clause
---@param node table Tree-sitter node (with_clause)
---@param query_text string Original query text
---@param scope QueryScope Scope to add CTEs to
function ScopeTracker._extract_ctes(node, query_text, scope)
  -- Pattern: WITH cte_name [(columns)] AS (select_statement)
  -- CTEs are visible to all queries after their definition

  for child in node:iter_children() do
    local child_type = child:type()

    if child_type == "cte" or child_type == "common_table_expression" then
      -- Extract CTE name
      local cte_name = nil
      local cte_columns = {}
      local start_row, start_col = child:range()

      for cte_child in child:iter_children() do
        local cte_child_type = cte_child:type()

        if cte_child_type == "identifier" and not cte_name then
          cte_name = vim.treesitter.get_node_text(cte_child, query_text)
          cte_name = ScopeTracker._clean_identifier(cte_name)
        elseif cte_child_type == "column_list" then
          -- Extract column definitions if present
          for col_child in cte_child:iter_children() do
            if col_child:type() == "identifier" then
              local col_name = vim.treesitter.get_node_text(col_child, query_text)
              table.insert(cte_columns, ScopeTracker._clean_identifier(col_name))
            end
          end
        end
      end

      if cte_name then
        scope.ctes[cte_name:lower()] = {
          name = cte_name,
          columns = cte_columns,
          start_pos = { start_row + 1, start_col },
        }
      end
    end
  end
end

---Extract SELECT scope (could be main query or subquery)
---@param node table Tree-sitter node (select_statement)
---@param query_text string Original query text
---@param parent_scope QueryScope Parent scope
function ScopeTracker._extract_select_scope(node, query_text, parent_scope)
  -- Check if this is a subquery (parent is not global)
  local start_row, start_col, end_row, end_col = node:range()

  -- Determine if this is a subquery context
  local is_subquery = false
  local parent = node:parent()
  if parent then
    local parent_type = parent:type()
    -- Subquery if inside parentheses, derived table, or IN clause
    if parent_type:match("subquery") or parent_type:match("derived") or parent_type:match("parenthesized") then
      is_subquery = true
    end
  end

  if is_subquery then
    -- Create subquery scope
    local subquery_scope = {
      type = "subquery",
      start_pos = { start_row + 1, start_col },
      end_pos = { end_row + 1, end_col },
      aliases = {},
      ctes = {},
      parent = parent_scope,
      children = {},
      temp_tables = {}, -- Placeholder for Phase 10.5
    }

    table.insert(parent_scope.children, subquery_scope)

    -- Extract aliases within this subquery scope
    ScopeTracker._extract_aliases_from_select(node, query_text, subquery_scope)
  else
    -- Main query: Extract aliases into parent scope
    ScopeTracker._extract_aliases_from_select(node, query_text, parent_scope)
  end
end

---Extract aliases from SELECT statement
---@param node table Tree-sitter node (select_statement)
---@param query_text string Original query text
---@param scope QueryScope Scope to add aliases to
function ScopeTracker._extract_aliases_from_select(node, query_text, scope)
  -- Walk children to find FROM and JOIN clauses
  for child in node:iter_children() do
    local child_type = child:type()

    if child_type:match("from") then
      ScopeTracker._extract_from_aliases(child, query_text, scope)
    elseif child_type:match("join") then
      ScopeTracker._extract_join_aliases(child, query_text, scope)
    end
  end
end

---Extract aliases from FROM clause
---@param node table Tree-sitter node (from_clause)
---@param query_text string Original query text
---@param scope QueryScope Scope to add aliases to
function ScopeTracker._extract_from_aliases(node, query_text, scope)
  -- Use Treesitter helper to extract table references
  local Treesitter = require('ssns.completion.metadata.treesitter')
  local ref = Treesitter._extract_table_from_node(node, query_text)

  if ref and ref.table then
    local table_name = ref.table
    if ref.schema then
      table_name = ref.schema .. "." .. ref.table
    end

    if ref.alias then
      -- Add alias mapping
      scope.aliases[ref.alias:lower()] = table_name
    end
  end
end

---Extract aliases from JOIN clause
---@param node table Tree-sitter node (join_clause)
---@param query_text string Original query text
---@param scope QueryScope Scope to add aliases to
function ScopeTracker._extract_join_aliases(node, query_text, scope)
  -- Use Treesitter helper to extract table references
  local Treesitter = require('ssns.completion.metadata.treesitter')
  local ref = Treesitter._extract_table_from_node(node, query_text)

  if ref and ref.table then
    local table_name = ref.table
    if ref.schema then
      table_name = ref.schema .. "." .. ref.table
    end

    if ref.alias then
      -- Add alias mapping
      scope.aliases[ref.alias:lower()] = table_name
    end
  end
end

---Get scope at cursor position
---Returns the innermost scope containing the cursor
---@param scope_tree QueryScope Global scope tree
---@param cursor_pos table {row, col} Cursor position (1-indexed)
---@return QueryScope scope The innermost scope containing cursor
function ScopeTracker.get_scope_at_cursor(scope_tree, cursor_pos)
  -- Recursively search scope tree
  return ScopeTracker._find_innermost_scope(scope_tree, cursor_pos)
end

---Helper: Find innermost scope containing cursor position
---@param scope QueryScope Current scope to search
---@param cursor_pos table {row, col} Cursor position (1-indexed)
---@return QueryScope scope Innermost scope or input scope if no children match
function ScopeTracker._find_innermost_scope(scope, cursor_pos)
  -- Check if cursor is within this scope
  if not ScopeTracker._is_position_in_scope(cursor_pos, scope) then
    return scope -- Return current scope (fallback)
  end

  -- Check children for more specific scope
  for _, child in ipairs(scope.children) do
    if ScopeTracker._is_position_in_scope(cursor_pos, child) then
      -- Recurse into child
      return ScopeTracker._find_innermost_scope(child, cursor_pos)
    end
  end

  -- No child contains cursor, return this scope
  return scope
end

---Get all table aliases available at cursor position
---Includes aliases from current scope and parent scopes
---@param scope_tree QueryScope Global scope tree
---@param cursor_pos table {row, col} Cursor position (1-indexed)
---@return table<string, string> aliases Alias -> table mapping
function ScopeTracker.get_available_aliases(scope_tree, cursor_pos)
  local scope = ScopeTracker.get_scope_at_cursor(scope_tree, cursor_pos)
  local aliases = {}

  -- Collect aliases from current scope and parent scopes
  local current = scope
  while current do
    -- Add aliases from current scope (don't override more specific ones)
    for alias, table_name in pairs(current.aliases) do
      if not aliases[alias] then
        aliases[alias] = table_name
      end
    end

    -- Move to parent scope
    current = current.parent
  end

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
    start_pos = { 1, 0 },
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

  -- If same row as end, check column
  if row == scope.end_pos[1] and col > scope.end_pos[2] then
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

return ScopeTracker
