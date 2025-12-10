---Table reference parser for SQL FROM/JOIN clauses
---Parses qualified table names with optional aliases and hints
---
---@module ssns.completion.parser.utils.table_reference

local Helpers = require('ssns.completion.parser.utils.helpers')
local QualifiedName = require('ssns.completion.parser.utils.qualified_name')
local AliasParser = require('ssns.completion.parser.utils.alias')

local TableReferenceParser = {}

---Internal: Parse table reference with hint handling
---@param state ParserState
---@param is_cte_func fun(name: string): boolean Function to check if name is a CTE
---@return TableReference?
local function parse_table_ref_internal(state, is_cte_func)
  local qualified = QualifiedName.parse(state)
  if not qualified then
    return nil
  end

  -- Skip function parameter list if present (for TVFs like: dbo.fn_Split(@param, ',') AS s)
  if state:is_type("paren_open") then
    state:skip_paren_contents()
  end

  local alias = AliasParser.parse(state)

  -- Handle table hints: WITH (NOLOCK, READPAST, etc.)
  -- SQL Server allows hints between table name and alias
  if not alias and state:is_keyword("WITH") then
    state:advance()  -- consume WITH
    if state:is_type("paren_open") then
      state:skip_paren_contents()  -- Use the new ParserState method
    end
    -- Try to parse alias after the hint
    alias = AliasParser.parse(state)
  end

  return {
    server = qualified.server,
    database = qualified.database,
    schema = qualified.schema,
    name = qualified.name,
    alias = alias,
    is_temp = Helpers.is_temp_table(qualified.name),
    is_global_temp = Helpers.is_global_temp_table(qualified.name),
    is_table_variable = Helpers.is_table_variable(qualified.name),
    is_cte = is_cte_func(qualified.name),
  }
end

---Parse a table reference with optional alias
---@param state ParserState
---@param scope ScopeContext? Optional scope for CTE detection
---@return TableReference?
function TableReferenceParser.parse(state, scope)
  return parse_table_ref_internal(state, function(name)
    return scope and scope:is_cte(name) or false
  end)
end

---Parse a table reference using legacy known_ctes table (backward compatibility)
---@param state ParserState
---@param known_ctes table<string, boolean>? Legacy CTE tracking table
---@return TableReference?
function TableReferenceParser.parse_legacy(state, known_ctes)
  return parse_table_ref_internal(state, function(name)
    -- CTE names are stored lowercase, so check with lowercase key
    return known_ctes and known_ctes[name:lower()] == true or false
  end)
end

return TableReferenceParser
