---@class SsnsCommands
---Command registration module for SSNS plugin
---Loads and registers all command modules
local M = {}

---Register all SSNS commands
---Called during plugin setup
function M.register()
  -- Load command modules
  local tree = require('nvim-ssns.commands.tree')
  local server = require('nvim-ssns.commands.server')
  local query = require('nvim-ssns.commands.query')
  local debug = require('nvim-ssns.commands.debug')
  local export = require('nvim-ssns.commands.export')
  local testing = require('nvim-ssns.commands.testing')
  local features = require('nvim-ssns.commands.features')
  local cast = require('nvim-ssns.commands.cast')

  -- Register each module's commands
  tree.register()
  server.register()
  query.register()
  debug.register()
  export.register()
  testing.register()
  features.register()
  cast.register()

  -- Note: ETL commands are lazy-loaded via ftplugin/ssns.lua
  -- when .ssns files are opened (see M.setup_etl below)
end

---Setup ETL commands and macros (lazy-loaded for .ssns files)
---Called from ftplugin/ssns.lua on first .ssns file open
function M.setup_etl()
  -- Only initialize once
  if vim.g.ssns_etl_initialized then
    return
  end
  vim.g.ssns_etl_initialized = true

  local etl = require('nvim-ssns.commands.etl')
  etl.setup()
end

return M
