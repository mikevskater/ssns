---@class SsnsCommands
---Command registration module for SSNS plugin
---Loads and registers all command modules
local M = {}

---Register all SSNS commands
---Called during plugin setup
function M.register()
  -- Load command modules
  local tree = require('ssns.commands.tree')
  local server = require('ssns.commands.server')
  local query = require('ssns.commands.query')
  local debug = require('ssns.commands.debug')
  local export = require('ssns.commands.export')
  local testing = require('ssns.commands.testing')
  local features = require('ssns.commands.features')

  -- Register each module's commands
  tree.register()
  server.register()
  query.register()
  debug.register()
  export.register()
  testing.register()
  features.register()
end

return M
