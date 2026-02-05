---@class SsnsApi
---Public API module for SSNS plugin
---Provides functions for external integration
local M = {}

-- Re-export api modules
M.diagnostics = require('nvim-ssns.api.diagnostics')
M.connections = require('nvim-ssns.api.connections')

return M
