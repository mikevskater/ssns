---@class SsnsApiConnections
---Connection management API functions
local M = {}

---Refresh all servers
function M.refresh_all()
  local Cache = require('ssns.cache')
  Cache.refresh_all()
  vim.notify("SSNS: Refreshed all servers", vim.log.levels.INFO)
end

---Connect to a saved connection
---@param connection_name string
function M.connect(connection_name)
  local Config = require('ssns.config')
  local Cache = require('ssns.cache')
  local Connections = require('ssns.connections')

  -- Check if already in cache
  local existing_server = Cache.find_server(connection_name)
  if existing_server then
    local success, err = existing_server:connect()
    if success then
      vim.notify(string.format("SSNS: Connected to '%s'", connection_name), vim.log.levels.INFO)
    else
      vim.notify(string.format("SSNS: Failed to connect to '%s': %s", connection_name, err), vim.log.levels.ERROR)
    end
    return
  end

  -- Get connection config from config or connections file
  local connection_config = nil

  -- First check config (now stores ConnectionData objects)
  local config_connections = Config.get_connections()
  connection_config = config_connections[connection_name]

  -- If not in config, check connections file
  if not connection_config then
    local file_conn = Connections.find(connection_name)
    if file_conn then
      connection_config = file_conn  -- file_conn IS the ConnectionData
    end
  end

  if not connection_config then
    vim.notify(string.format("SSNS: Connection '%s' not found", connection_name), vim.log.levels.ERROR)
    return
  end

  -- Create and add server
  local Factory = require('ssns.factory')
  local server, err = Factory.create_server(connection_name, connection_config)

  if not server then
    vim.notify(string.format("SSNS: Failed to create connection '%s': %s", connection_name, err), vim.log.levels.ERROR)
    return
  end

  Cache.add_server(server)

  -- Connect
  local success, connect_err = server:connect()
  if success then
    vim.notify(string.format("SSNS: Connected to '%s'", connection_name), vim.log.levels.INFO)
  else
    vim.notify(string.format("SSNS: Failed to connect to '%s': %s", connection_name, connect_err), vim.log.levels.ERROR)
  end
end

---Attach current buffer to a connection (flat picker)
function M.attach()
  local ConnectionPicker = require('ssns.ui.pickers.connection_picker')
  ConnectionPicker.show()
end

---Attach current buffer to a connection (hierarchical picker)
function M.attach_pick()
  local ConnectionPicker = require('ssns.ui.pickers.connection_picker')
  ConnectionPicker.show_hierarchical()
end

---Detach connection from current buffer
function M.detach()
  local ConnectionPicker = require('ssns.ui.pickers.connection_picker')
  ConnectionPicker.detach()
end

---Get current connection info for buffer
---@param bufnr number? Buffer number (defaults to current)
---@return string? db_key The connection key or nil
function M.get_connection(bufnr)
  local ConnectionPicker = require('ssns.ui.pickers.connection_picker')
  return ConnectionPicker.get_current_connection(bufnr)
end

---Change database for current server connection
function M.change_database()
  local ConnectionPicker = require('ssns.ui.pickers.connection_picker')
  ConnectionPicker.show_database_picker()
end

---Show query history
function M.show_history()
  local UiHistory = require('ssns.ui.panels.history')
  UiHistory.show_history()
end

---Show database object search UI
function M.show_object_search()
  local UiObjectSearch = require('ssns.ui.panels.object_search')
  UiObjectSearch.show()
end

---Clear query history
function M.clear_history()
  local QueryHistory = require('ssns.query_history')
  QueryHistory.clear_all()
end

---Export query history
---@param filepath string? Optional file path
function M.export_history(filepath)
  local QueryHistory = require('ssns.query_history')

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
