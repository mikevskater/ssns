--- ScopeContext for tracking nested SQL statement context
--- Used to properly handle correlated subqueries, CTEs, and alias visibility

require('nvim-ssns.completion.parser.types')

---@class ScopeContext
---@field parent ScopeContext? Parent scope (for correlated subqueries)
---@field tables TableReference[] Tables visible in current scope
---@field aliases table<string, TableReference> Alias -> TableReference mapping
---@field ctes table<string, CTEInfo> CTEs visible (inherited from parent + local)
---@field subqueries SubqueryInfo[] Subqueries defined in this scope
---@field depth number Nesting depth (0 = top level)
---@field statement_type string? Type of statement in this scope

local ScopeContext = {}
ScopeContext.__index = ScopeContext

---Create a new scope context
---@param parent ScopeContext? Parent scope for nested queries
---@return ScopeContext
function ScopeContext.new(parent)
  local self = setmetatable({}, ScopeContext)
  self.parent = parent
  self.tables = {}
  self.aliases = {}
  -- CTEs are inherited from parent scope (visible to nested queries)
  self.ctes = parent and vim.deepcopy(parent.ctes) or {}
  self.subqueries = {}
  self.depth = parent and (parent.depth + 1) or 0
  self.statement_type = nil
  return self
end

---Add a table to this scope
---@param table_ref TableReference
function ScopeContext:add_table(table_ref)
  table.insert(self.tables, table_ref)
  if table_ref.alias then
    self.aliases[table_ref.alias:lower()] = table_ref
  end
end

---Add a CTE to this scope
---@param name string CTE name
---@param cte CTEInfo CTE definition
function ScopeContext:add_cte(name, cte)
  self.ctes[name:lower()] = cte
end

---Check if a name refers to a CTE
---@param name string Name to check
---@return boolean
function ScopeContext:is_cte(name)
  return self.ctes[name:lower()] ~= nil
end

---Get CTE by name
---@param name string CTE name
---@return CTEInfo?
function ScopeContext:get_cte(name)
  return self.ctes[name:lower()]
end

---Get all visible tables (including from parent scopes for correlated refs)
---@return TableReference[]
function ScopeContext:get_visible_tables()
  local visible = {}
  -- Add tables from current scope
  for _, tbl in ipairs(self.tables) do
    table.insert(visible, tbl)
  end
  -- Add tables from parent scope (for correlated subqueries)
  if self.parent then
    for _, tbl in ipairs(self.parent:get_visible_tables()) do
      table.insert(visible, tbl)
    end
  end
  return visible
end

---Get alias mapping including parent scopes
---@return table<string, TableReference>
function ScopeContext:get_visible_aliases()
  local aliases = {}
  -- Start with parent aliases (can be overridden by local)
  if self.parent then
    for k, v in pairs(self.parent:get_visible_aliases()) do
      aliases[k] = v
    end
  end
  -- Local aliases override parent
  for k, v in pairs(self.aliases) do
    aliases[k] = v
  end
  return aliases
end

---Resolve an alias to a TableReference
---@param alias string Alias to resolve
---@return TableReference?
function ScopeContext:resolve_alias(alias)
  local lower = alias:lower()
  -- Check local aliases first
  if self.aliases[lower] then
    return self.aliases[lower]
  end
  -- Check parent scope
  if self.parent then
    return self.parent:resolve_alias(alias)
  end
  return nil
end

---Add a subquery to this scope
---@param subquery SubqueryInfo
function ScopeContext:add_subquery(subquery)
  table.insert(self.subqueries, subquery)
end

---Get known CTEs as a simple name -> true table (for backward compatibility)
---This is used by functions that need a simple CTE lookup table rather than full CTEInfo
---@return table<string, boolean>
function ScopeContext:get_known_ctes_table()
  local known = {}
  for name, _ in pairs(self.ctes) do
    known[name] = true
  end
  return known
end

---Create a child scope for a nested query
---@return ScopeContext
function ScopeContext:create_child()
  return ScopeContext.new(self)
end

return ScopeContext
