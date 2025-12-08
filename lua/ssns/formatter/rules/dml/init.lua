---@class DmlRules
---DML (Data Manipulation Language) formatting rules module.
---Loads and exports all DML statement formatting rules.
local DmlRules = {}

-- Load DML rule modules
DmlRules.insert = require('ssns.formatter.rules.dml.insert')
DmlRules.update = require('ssns.formatter.rules.dml.update')
DmlRules.delete = require('ssns.formatter.rules.dml.delete')
DmlRules.merge = require('ssns.formatter.rules.dml.merge')

return DmlRules
