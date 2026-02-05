---@class SsnsCommandsServer
---Server and connection related commands
local M = {}

---Register server/connection commands
function M.register()
  local Ssns = require('nvim-ssns')

  -- :SSNSRefresh - Refresh all servers
  vim.api.nvim_create_user_command("SSNSRefresh", function()
    Ssns.refresh_all()
  end, {
    desc = "Refresh all SSNS servers",
  })

  -- :SSNSConnect <name> - Connect to a saved connection
  vim.api.nvim_create_user_command("SSNSConnect", function(opts)
    Ssns.connect(opts.args)
  end, {
    nargs = 1,
    desc = "Connect to a saved SSNS connection",
    complete = function()
      local Config = require('nvim-ssns.config')
      local Connections = require('nvim-ssns.connections')
      local names = {}

      -- Get from config
      local config_connections = Config.get_connections()
      for name, _ in pairs(config_connections) do
        table.insert(names, name)
      end

      -- Get from connections file
      local file_connections = Connections.load()
      for _, conn in ipairs(file_connections) do
        -- Avoid duplicates
        local exists = false
        for _, n in ipairs(names) do
          if n == conn.name then
            exists = true
            break
          end
        end
        if not exists then
          table.insert(names, conn.name)
        end
      end

      return names
    end,
  })

  -- :SSNSAddServer - Open add server UI
  vim.api.nvim_create_user_command("SSNSAddServer", function()
    local AddServerUI = require('nvim-ssns.ui.dialogs.add_server')
    AddServerUI.open()
  end, {
    nargs = 0,
    desc = "Add a new server connection",
  })

  -- :SSNSAttach - Attach current SQL buffer to a connection
  vim.api.nvim_create_user_command("SSNSAttach", function()
    local ConnectionPicker = require('nvim-ssns.ui.pickers.connection_picker')
    ConnectionPicker.show()
  end, {
    nargs = 0,
    desc = "Attach current SQL buffer to a saved connection",
  })

  -- :SSNSAttachPick - Attach with hierarchical server/database picker
  vim.api.nvim_create_user_command("SSNSAttachPick", function()
    local ConnectionPicker = require('nvim-ssns.ui.pickers.connection_picker')
    ConnectionPicker.show_hierarchical()
  end, {
    nargs = 0,
    desc = "Attach current SQL buffer to a connection (server then database)",
  })

  -- :SSNSDetach - Detach connection from current buffer
  vim.api.nvim_create_user_command("SSNSDetach", function()
    local ConnectionPicker = require('nvim-ssns.ui.pickers.connection_picker')
    ConnectionPicker.detach()
  end, {
    nargs = 0,
    desc = "Detach SSNS connection from current buffer",
  })

  -- :SSNSConnectionInfo - Show current connection info
  vim.api.nvim_create_user_command("SSNSConnectionInfo", function()
    local ConnectionPicker = require('nvim-ssns.ui.pickers.connection_picker')
    local db_key = ConnectionPicker.get_current_connection()
    if db_key then
      vim.notify(string.format("SSNS: Current connection: %s", db_key), vim.log.levels.INFO)
    else
      vim.notify("SSNS: No connection attached to this buffer", vim.log.levels.INFO)
    end
  end, {
    nargs = 0,
    desc = "Show current SSNS connection for this buffer",
  })

  -- :SSNSChangeDatabase - Change database for current server connection
  vim.api.nvim_create_user_command("SSNSChangeDatabase", function()
    local ConnectionPicker = require('nvim-ssns.ui.pickers.connection_picker')
    ConnectionPicker.show_database_picker()
  end, {
    nargs = 0,
    desc = "Change database for current server connection",
  })

  -- :SSNSManageConnections - Open connection manager (alias for SSNSAddServer)
  vim.api.nvim_create_user_command("SSNSManageConnections", function()
    local AddServerUI = require('nvim-ssns.ui.dialogs.add_server')
    AddServerUI.open()
  end, {
    nargs = 0,
    desc = "Manage saved server connections",
  })

  -- :SSNSStats - Show cache statistics
  vim.api.nvim_create_user_command("SSNSStats", function()
    Ssns.show_stats()
  end, {
    desc = "Show SSNS cache statistics",
  })

  -- :SSNSDebug - Debug cache contents (simple print)
  vim.api.nvim_create_user_command("SSNSDebug", function()
    Ssns.debug()
  end, {
    desc = "Debug SSNS cache contents",
  })
end

return M
