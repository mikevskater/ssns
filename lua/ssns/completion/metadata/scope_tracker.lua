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

  debug_log("Scope tree built")
  debug_log("GlobalScope children count: " .. #global_scope.children)
  debug_log("GlobalScope aliases: " .. vim.inspect(global_scope.aliases))

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

  -- Process different node types
  if node_type == "statement" then
    -- Statement container: Process as a SELECT scope
    ScopeTracker._extract_select_scope(node, query_text, parent_scope)
    return  -- Don't recurse - _extract_select_scope handles children
  elseif node_type:match("with_clause") or node_type == "cte_clause" then
    ScopeTracker._extract_ctes(node, query_text, parent_scope)
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

---Extract scope from a statement node (contains select + from as siblings)
---@param node table Tree-sitter node (statement)
---@param query_text string Original query text
---@param parent_scope QueryScope Parent scope to add child to
function ScopeTracker._extract_select_scope(node, query_text, parent_scope)
  local start_row, start_col, end_row, end_col = node:range()

  debug_log(string.format("_extract_select_scope: Creating scope for statement at lines %d-%d",
    start_row + 1, end_row + 1))

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
  local select_scope = {
    type = scope_type,
    start_pos = {start_row + 1, start_col},
    end_pos = {end_row + 1, end_col},
    aliases = {},
    ctes = {},
    parent = parent_scope,
    children = {},
    temp_tables = {},
  }

  debug_log(string.format("Created scope: start={%d,%d}, end={%d,%d}",
    select_scope.start_pos[1], select_scope.start_pos[2],
    select_scope.end_pos[1], select_scope.end_pos[2]))

  -- Add to parent
  table.insert(parent_scope.children, select_scope)

  -- Extract aliases from the statement's children
  -- In real AST: statement has "select" and "from" as SIBLING children
  ScopeTracker._extract_aliases_from_statement(node, query_text, select_scope)

  debug_log(string.format("Extracted aliases: %s", vim.inspect(select_scope.aliases)))
  debug_log(string.format("Parent scope now has %d children", #parent_scope.children))

  -- Recurse into nested statements (e.g., subqueries)
  for child in node:iter_children() do
    ScopeTracker._build_scope_tree_recursive(child, query_text, select_scope)
  end
end

---Extract aliases from statement node (select + from are siblings)
---@param node table Tree-sitter node (statement)
---@param query_text string Original query text
---@param scope QueryScope Scope to add aliases to
function ScopeTracker._extract_aliases_from_statement(node, query_text, scope)
  -- Walk children to find FROM and JOIN clauses
  -- NOTE: In real AST, FROM is a SIBLING of SELECT, not a child of SELECT
  for child in node:iter_children() do
    local child_type = child:type()

    if child_type == "from" then
      debug_log(string.format("Found FROM clause at %s", child_type))
      ScopeTracker._extract_from_aliases(child, query_text, scope)
    elseif child_type:match("join") then
      debug_log(string.format("Found JOIN clause at %s", child_type))
      ScopeTracker._extract_join_aliases(child, query_text, scope)
    end
  end
end

---Extract aliases from FROM clause (real AST structure)
---@param node table Tree-sitter node (from)
---@param query_text string Original query text
---@param scope QueryScope Scope to add aliases to
function ScopeTracker._extract_from_aliases(node, query_text, scope)
  -- Real AST structure:
  -- from
  --   └─ relation "dbo.Employees e"
  --       ├─ object_reference "dbo.Employees"  (could be dotted: dbo.Employees)
  --       └─ identifier "e"  (the alias)

  for child in node:iter_children() do
    local child_type = child:type()

    if child_type == "relation" then
      -- Found a table reference
      local table_parts = {}
      local alias = nil

      -- Get children of relation: object_reference + optional identifier (alias)
      for relation_child in child:iter_children() do
        local relation_child_type = relation_child:type()

        if relation_child_type == "object_reference" then
          -- Extract table name (may be schema.table)
          local table_name = vim.treesitter.get_node_text(relation_child, query_text)
          table.insert(table_parts, table_name)
        elseif relation_child_type == "identifier" then
          -- This is the alias
          alias = vim.treesitter.get_node_text(relation_child, query_text)
        end
      end

      if #table_parts > 0 and alias then
        local full_table_name = table.concat(table_parts, ".")
        scope.aliases[alias:lower()] = full_table_name
        debug_log(string.format("Extracted alias: %s -> %s", alias, full_table_name))
      end
    end
  end
end

---Extract aliases from JOIN clause (real AST structure)
---@param node table Tree-sitter node (join_clause or join variant)
---@param query_text string Original query text
---@param scope QueryScope Scope to add aliases to
function ScopeTracker._extract_join_aliases(node, query_text, scope)
  -- Real AST structure similar to FROM:
  -- join_clause
  --   └─ relation "dbo.TableName alias"
  --       ├─ object_reference "dbo.TableName"
  --       └─ identifier "alias"

  for child in node:iter_children() do
    local child_type = child:type()

    if child_type == "relation" then
      -- Found a table reference in the JOIN
      local table_parts = {}
      local alias = nil

      -- Get children of relation: object_reference + optional identifier (alias)
      for relation_child in child:iter_children() do
        local relation_child_type = relation_child:type()

        if relation_child_type == "object_reference" then
          -- Extract table name (may be schema.table)
          local table_name = vim.treesitter.get_node_text(relation_child, query_text)
          table.insert(table_parts, table_name)
        elseif relation_child_type == "identifier" then
          -- This is the alias
          alias = vim.treesitter.get_node_text(relation_child, query_text)
        end
      end

      if #table_parts > 0 and alias then
        local full_table_name = table.concat(table_parts, ".")
        scope.aliases[alias:lower()] = full_table_name
        debug_log(string.format("Extracted JOIN alias: %s -> %s", alias, full_table_name))
      end
    end
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
