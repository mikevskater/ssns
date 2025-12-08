---@class BaseRules
---Base formatting rules module.
---Loads and exports all base formatting rules.
local BaseRules = {}

-- Load base rule modules
BaseRules.indentation = require('ssns.formatter.rules.base.indentation')
BaseRules.spacing = require('ssns.formatter.rules.base.spacing')
BaseRules.keywords = require('ssns.formatter.rules.base.keywords')
BaseRules.alignment = require('ssns.formatter.rules.base.alignment')

return BaseRules
