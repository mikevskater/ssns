---@class SsnsApiConnections
---Connection management API functions
local M = {}

---Refresh all servers
function M.refresh_all()
  local Cache = require('nvim-ssns.cache')
  Cache.refresh_all()
  vim.notify("SSNS: Refreshed all servers", vim.log.levels.INFO)
end

---Connect to a saved connection
---@param connection_name string
function M.connect(connection_name)
  local Config = require('nvim-ssns.config')
  local Cache = require('nvim-ssns.cache')
  local Connections = require('nvim-ssns.connections')

  -- Helper to connect server and notify
  local function do_connect(server)
    server:connect_async(function(success, err)
      if success then
        vim.notify(string.format("SSNS: Connected to '%s'", connection_name), vim.log.levels.INFO)
      else
        vim.notify(string.format("SSNS: Failed to connect to '%s': %s", connection_name, err), vim.log.levels.ERROR)
      end
    end)
  end

  -- Check if already in cache
  local existing_server = Cache.find_server(connection_name)
  if existing_server then
    do_connect(existing_server)
    return
  end

  -- First check config (now stores ConnectionData objects)
  local config_connections = Config.get_connections()
  local connection_config = config_connections[connection_name]

  if connection_config then
    -- Found in config, create and connect
    local Factory = require('nvim-ssns.factory')
    local server, err = Factory.create_server(connection_name, connection_config)
    if not server then
      vim.notify(string.format("SSNS: Failed to create connection '%s': %s", connection_name, err), vim.log.levels.ERROR)
      return
    end
    Cache.add_server(server)
    do_connect(server)
    return
  end

  -- If not in config, check connections file asynchronously
  Connections.find_async(connection_name, function(file_conn, find_err)
    if find_err then
      vim.notify(string.format("SSNS: Error finding connection '%s': %s", connection_name, find_err), vim.log.levels.ERROR)
      return
    end

    if not file_conn then
      vim.notify(string.format("SSNS: Connection '%s' not found", connection_name), vim.log.levels.ERROR)
      return
    end

    -- Create and add server
    local Factory = require('nvim-ssns.factory')
    local server, err = Factory.create_server(connection_name, file_conn)
    if not server then
      vim.notify(string.format("SSNS: Failed to create connection '%s': %s", connection_name, err), vim.log.levels.ERROR)
      return
    end

    Cache.add_server(server)
    do_connect(server)
  end)
end

---Attach current buffer to a connection (flat picker)
function M.attach()
  local ConnectionPicker = require('nvim-ssns.ui.pickers.connection_picker')
  ConnectionPicker.show()
end

---Attach current buffer to a connection (hierarchical picker)
function M.attach_pick()
  local ConnectionPicker = require('nvim-ssns.ui.pickers.connection_picker')
  ConnectionPicker.show_hierarchical()
end

---Detach connection from current buffer
function M.detach()
  local ConnectionPicker = require('nvim-ssns.ui.pickers.connection_picker')
  ConnectionPicker.detach()
end

---Get current connection info for buffer
---@param bufnr number? Buffer number (defaults to current)
---@return string? db_key The connection key or nil
function M.get_connection(bufnr)
  local ConnectionPicker = require('nvim-ssns.ui.pickers.connection_picker')
  return ConnectionPicker.get_current_connection(bufnr)
end

---Change database for current server connection
function M.change_database()
  local ConnectionPicker = require('nvim-ssns.ui.pickers.connection_picker')
  ConnectionPicker.show_database_picker()
end

---Show query history
function M.show_history()
  local UiHistory = require('nvim-ssns.ui.panels.history')
  UiHistory.show_history()
end

---Show database object search UI
function M.show_object_search()
  local UiObjectSearch = require('nvim-ssns.ui.panels.object_search')
  UiObjectSearch.show()
end

---Clear query history
function M.clear_history()
  local QueryHistory = require('nvim-ssns.query_history')
  QueryHistory.clear_all()
end

---Export query history
---@param filepath string? Optional file path
function M.export_history(filepath)
  local QueryHistory = require('nvim-ssns.query_history')

  if not filepath or filepath == "" then
    filepath = vim.fn.stdpath('data') .. '/ssns/history_export.txt'
  end

  local format = filepath:match("%.([^.]+)$")
  if format == "json" then
    format = "json"
  else
    format = "txt"
  end

  if QueryHistory.export(filepath, format) then
    vim.notify("History exported to " .. filepath, vim.log.levels.INFO)
  end
end

return M
