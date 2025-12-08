---@class RuleRegistry
---Rule registry and loader for the SQL formatter.
---Manages loading and applying formatting rules.
---
---Directory Structure:
---  rules/
---  ├── init.lua          # This file - registry
---  ├── base/             # Core formatting (indentation, spacing, keywords, alignment)
---  ├── clauses/          # Statement clauses (SELECT, FROM, JOIN, WHERE, GROUP BY, CTE)
---  ├── dml/              # DML statements (INSERT, UPDATE, DELETE, MERGE)
---  └── ddl/              # DDL statements (CREATE, ALTER) - Phase 4
---
local RuleRegistry = {}

---@type table<string, FormatterRule>
local rules = {}

---Register a formatting rule
---@param name string Rule name
---@param rule FormatterRule Rule implementation
function RuleRegistry.register(name, rule)
  rules[name] = rule
end

---Get a registered rule
---@param name string Rule name
---@return FormatterRule|nil
function RuleRegistry.get(name)
  return rules[name]
end

---Get all registered rules
---@return table<string, FormatterRule>
function RuleRegistry.get_all()
  return rules
end

---Load all default rules from the modular structure
function RuleRegistry.load_defaults()
  -- Load base rules
  local base = require('ssns.formatter.rules.base')
  RuleRegistry.register('indentation', base.indentation)
  RuleRegistry.register('spacing', base.spacing)
  RuleRegistry.register('keywords', base.keywords)
  RuleRegistry.register('alignment', base.alignment)

  -- Load clause rules
  local clauses = require('ssns.formatter.rules.clauses')
  RuleRegistry.register('select', clauses.select)
  RuleRegistry.register('from', clauses.from)
  RuleRegistry.register('join', clauses.join)
  RuleRegistry.register('where', clauses.where)
  RuleRegistry.register('groupby', clauses.groupby)
  RuleRegistry.register('cte', clauses.cte)

  -- Load DML rules
  local dml = require('ssns.formatter.rules.dml')
  RuleRegistry.register('insert', dml.insert)
  RuleRegistry.register('update', dml.update)
  RuleRegistry.register('delete', dml.delete)
  RuleRegistry.register('merge', dml.merge)

  -- DDL rules will be added in Phase 4
  -- local ddl = require('ssns.formatter.rules.ddl')
end

---Apply all rules to a token
---@param token Token
---@param context FormatterState
---@param config FormatterConfig
---@return Token
function RuleRegistry.apply_all(token, context, config)
  local result = token
  for _, rule in pairs(rules) do
    if rule.apply then
      result = rule.apply(result, context, config)
    end
  end
  return result
end

---Get rule module by category
---@param category string "base"|"clauses"|"dml"|"ddl"
---@return table
function RuleRegistry.get_category(category)
  if category == "base" then
    return require('ssns.formatter.rules.base')
  elseif category == "clauses" then
    return require('ssns.formatter.rules.clauses')
  elseif category == "dml" then
    return require('ssns.formatter.rules.dml')
  elseif category == "ddl" then
    return require('ssns.formatter.rules.ddl')
  end
  return {}
end

return RuleRegistry
