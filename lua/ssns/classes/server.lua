local BaseDbObject = require('ssns.classes.base')

---@class ConnectionState
---@field DISCONNECTED string
---@field CONNECTING string
---@field CONNECTED string
---@field ERROR string

---Connection state constants
---@type ConnectionState
local ConnectionState = {
  DISCONNECTED = "disconnected",
  CONNECTING = "connecting",
  CONNECTED = "connected",
  ERROR = "error",
}

---@class ServerClass : BaseDbObject
---@field connection_string string The database connection string
---@field connection_state string Current connection state
---@field adapter BaseAdapter Database-specific adapter
---@field connection any Active database connection object
---@field databases DbClass[]? Array of database objects
---@field error_message string? Error message if connection failed
---@field last_connected_at number? Timestamp of last successful connection
local ServerClass = setmetatable({}, { __index = BaseDbObject })
ServerClass.__index = ServerClass

---Create a new Server instance
---@param opts {name: string, connection_string: string}
---@return ServerClass
function ServerClass.new(opts)
  -- Create base object
  local self = setmetatable(BaseDbObject.new({
    name = opts.name,
    parent = nil,  -- Server is root level
  }), ServerClass)

  self.connection_string = opts.connection_string
  self.connection_state = ConnectionState.DISCONNECTED
  self.connection = nil
  self.databases = nil
  self.error_message = nil
  self.last_connected_at = nil

  -- Create adapter from connection string
  local AdapterFactory = require('ssns.adapters.factory')
  local adapter, err = AdapterFactory.create_adapter(self.connection_string)

  if not adapter then
    self.error_message = err or "Failed to create adapter"
    self.connection_state = ConnectionState.ERROR
  end

  self.adapter = adapter

  -- Set appropriate icon for server
  self.ui_state.icon = ""  -- Server icon

  return self
end

---Get the database type for this server
---@return string? db_type
function ServerClass:get_db_type()
  return self.adapter and self.adapter.db_type or nil
end

---Check if server is connected
---@return boolean
function ServerClass:is_connected()
  return self.connection_state == ConnectionState.CONNECTED
end

---Check if server has an error
---@return boolean
function ServerClass:has_error()
  return self.connection_state == ConnectionState.ERROR
end

---Connect to the database server
---@return boolean success
---@return string? error_message
function ServerClass:connect()
  if self.connection_state == ConnectionState.CONNECTED then
    return true, nil
  end

  if not self.adapter then
    return false, self.error_message or "No adapter available"
  end

  self.connection_state = ConnectionState.CONNECTING
  self.error_message = nil

  -- TODO: Implement actual connection via vim-dadbod
  -- For now, simulate successful connection
  -- This will be implemented in Phase 3 (Connection Management)

  -- Placeholder: Mark as connected
  self.connection_state = ConnectionState.CONNECTED
  self.last_connected_at = os.time()

  return true, nil
end

---Disconnect from the database server
function ServerClass:disconnect()
  if self.connection_state == ConnectionState.DISCONNECTED then
    return
  end

  -- TODO: Close actual connection
  -- For now, just reset state

  self.connection = nil
  self.connection_state = ConnectionState.DISCONNECTED
  self.last_connected_at = nil

  -- Clear loaded databases (will need to reconnect and reload)
  self:clear_children()
end

---Toggle connection state (connect if disconnected, disconnect if connected)
---@return boolean success
---@return string? error_message
function ServerClass:toggle_connection()
  if self:is_connected() then
    self:disconnect()
    return true, nil
  else
    return self:connect()
  end
end

---Test the connection without changing state
---@return boolean success
---@return string? error_message
function ServerClass:test_connection()
  if not self.adapter then
    return false, self.error_message or "No adapter available"
  end

  -- TODO: Implement actual connection test
  -- For now, assume success
  return true, nil
end

---Load databases from the server (lazy loading)
---@return boolean success
function ServerClass:load()
  if self.is_loaded then
    return true
  end

  -- Ensure connected before loading
  if not self:is_connected() then
    local success, err = self:connect()
    if not success then
      self.error_message = err
      return false
    end
  end

  -- Get databases query from adapter
  local query = self.adapter:get_databases_query()

  -- Execute query
  -- TODO: Implement actual execution via vim-dadbod
  -- For now, return empty results
  local results = self.adapter:execute(self.connection, query)

  -- Parse results
  local databases = self.adapter:parse_databases(results)

  -- Create database objects
  self:clear_children()
  for _, db_data in ipairs(databases) do
    local DbClass = require('ssns.classes.database')
    local db = DbClass.new({
      name = db_data.name,
      parent = self,
    })
    -- add_child is called automatically in DbClass.new via parent parameter
  end

  self.is_loaded = true
  return true
end

---Reload databases from server
---@return boolean success
function ServerClass:reload()
  self:clear_children()
  return self:load()
end

---Find a database by name
---@param database_name string
---@return DbClass?
function ServerClass:find_database(database_name)
  return self:find_child(database_name)
end

---Get all databases
---@return DbClass[]
function ServerClass:get_databases()
  if not self.is_loaded then
    self:load()
  end
  return self.children
end

---Get connection status indicator for UI
---@return string status_icon "✓" for connected, "✗" for error, "" for disconnected
function ServerClass:get_status_icon()
  if self.connection_state == ConnectionState.CONNECTED then
    return "✓"
  elseif self.connection_state == ConnectionState.ERROR then
    return "✗"
  elseif self.connection_state == ConnectionState.CONNECTING then
    return "⋯"
  else
    return ""
  end
end

---Get display name with connection status
---@return string
function ServerClass:get_display_name()
  local status = self:get_status_icon()
  if status ~= "" then
    return string.format("%s %s", self.name, status)
  end
  return self.name
end

---Override adapter retrieval (server IS the adapter source)
---@return BaseAdapter
function ServerClass:get_adapter()
  return self.adapter
end

---Get server (override base - server returns self)
---@return ServerClass
function ServerClass:get_server()
  return self
end

---Get string representation for debugging
---@return string
function ServerClass:to_string()
  return string.format(
    "ServerClass{name=%s, state=%s, db_type=%s, databases=%d}",
    self.name,
    self.connection_state,
    self:get_db_type() or "unknown",
    #self.children
  )
end

-- Export ConnectionState with the class
ServerClass.ConnectionState = ConnectionState

return ServerClass
