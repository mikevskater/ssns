---@class ClauseRules
---Clause-specific formatting rules module.
---Loads and exports all clause formatting rules.
local ClauseRules = {}

-- Load clause rule modules
ClauseRules.select = require('ssns.formatter.rules.clauses.select')
ClauseRules.from = require('ssns.formatter.rules.clauses.from')
ClauseRules.join = require('ssns.formatter.rules.clauses.join')
ClauseRules.where = require('ssns.formatter.rules.clauses.where')
ClauseRules.groupby = require('ssns.formatter.rules.clauses.groupby')
ClauseRules.cte = require('ssns.formatter.rules.clauses.cte')

return ClauseRules
