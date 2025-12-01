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

  -- Set object type for highlighting
  self.object_type = "server"

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

  -- Use connection module to establish connection
  local ConnectionModule = require('ssns.connection')

  -- Test the connection
  local success, err = ConnectionModule.test(self.connection_string)

  if not success then
    self.connection_state = ConnectionState.ERROR
    self.error_message = err or "Connection test failed"
    return false, self.error_message
  end

  -- Create or get connection from pool
  self.connection = ConnectionModule.get_or_create(self.connection_string)

  -- Mark as connected
  self.connection_state = ConnectionState.CONNECTED
  self.last_connected_at = os.time()

  -- Eagerly load metadata for completion if enabled
  local Config = require('ssns.config')
  local config = Config.get()
  if config.completion and config.completion.eager_load then
    -- Load databases in background to avoid blocking
    vim.schedule(function()
      -- Load databases
      local load_success = self:load()
      if not load_success then
        -- Silent failure - metadata will be loaded on-demand if eager load fails
        if config.completion.debug then
          vim.notify(
            string.format("SSNS: Failed to eagerly load metadata for '%s'", self.name),
            vim.log.levels.WARN
          )
        end
      end

      -- For each database, trigger load() to populate objects
      if load_success and self.databases then
        for _, db in ipairs(self.databases) do
          vim.schedule(function()
            local db_load_success = db:load()
            if not db_load_success and config.completion.debug then
              vim.notify(
                string.format("SSNS: Failed to eagerly load database '%s'", db.name),
                vim.log.levels.WARN
              )
            end
          end)
        end
      end
    end)
  end

  return true, nil
end

---Disconnect from the database server
function ServerClass:disconnect()
  if self.connection_state == ConnectionState.DISCONNECTED then
    return
  end

  -- Close connection in pool
  local ConnectionModule = require('ssns.connection')
  ConnectionModule.close(self.connection_string)

  self.connection = nil
  self.connection_state = ConnectionState.DISCONNECTED
  self.last_connected_at = nil

  -- Clear loaded databases (will need to reconnect and reload)
  self.databases = nil
  self.is_loaded = false
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

  local ConnectionModule = require('ssns.connection')
  return ConnectionModule.test(self.connection_string)
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

  -- Initialize databases array
  self.databases = {}

  -- Load databases from adapter
  local success, query = pcall(self.adapter.get_databases_query, self.adapter)
  if not success then
    self.error_message = "Failed to get databases query: " .. tostring(query)
    vim.notify("SSNS Error: " .. self.error_message, vim.log.levels.ERROR)
    return false
  end

  local results
  success, results = pcall(self.adapter.execute, self.adapter, self.connection, query)
  if not success then
    self.error_message = "Failed to execute databases query: " .. tostring(results)
    vim.notify("SSNS Error: " .. self.error_message, vim.log.levels.ERROR)
    return false
  end

  local databases
  success, databases = pcall(self.adapter.parse_databases, self.adapter, results)
  if not success then
    self.error_message = "Failed to parse databases: " .. tostring(databases)
    vim.notify("SSNS Error: " .. self.error_message, vim.log.levels.ERROR)
    return false
  end

  -- Create database objects in direct array (NOT in group container)
  for _, db_data in ipairs(databases) do
    local DbClass = require('ssns.classes.database')
    local db = DbClass.new({
      name = db_data.name,
      parent = self,  -- Parent is server directly
    })
    table.insert(self.databases, db)
  end

  self.is_loaded = true
  return true
end

---Reload databases from server
---@return boolean success
function ServerClass:reload()
  -- Invalidate query cache for this server's connection
  local Connection = require('ssns.connection')
  Connection.invalidate_cache(self.connection_string)

  -- Clear databases array and reset loaded state
  self.databases = nil
  self.is_loaded = false
  local load_success = self:load()

  -- Eagerly load metadata for completion if enabled
  local Config = require('ssns.config')
  local config = Config.get()
  if config.completion and config.completion.eager_load and load_success and self.databases then
    -- For each database, trigger load() to populate objects
    for _, db in ipairs(self.databases) do
      vim.schedule(function()
        local db_load_success = db:load()
        if not db_load_success and config.completion.debug then
          vim.notify(
            string.format("SSNS: Failed to eagerly load database '%s'", db.name),
            vim.log.levels.WARN
          )
        end
      end)
    end
  end

  return load_success
end

---Find a database by name (legacy - use get_database instead)
---@param database_name string
---@return DbClass?
function ServerClass:find_database(database_name)
  return self:get_database(database_name)
end

---Get a database by name
---@param database_name string
---@return DbClass?
function ServerClass:get_database(database_name)
  -- Lazy-load the server if not loaded
  if not self.is_loaded then
    local success = self:load()
    if not success then
      return nil
    end
  end

  -- Search databases array directly (case-insensitive)
  local lower_name = database_name:lower()
  for _, db in ipairs(self.databases or {}) do
    local db_name = db.db_name or db.name
    if db_name and db_name:lower() == lower_name then
      return db
    end
  end

  return nil
end

---Get all databases
---@return DbClass[]
function ServerClass:get_databases()
  if not self.is_loaded then
    self:load()
  end
  return self.databases or {}
end

---Get connection status indicator for UI
---@return string status_icon Icon from config for current connection state
function ServerClass:get_status_icon()
  local Config = require('ssns.config')
  local icons = Config.get_ui().icons

  if self.connection_state == ConnectionState.CONNECTED then
    return icons.connected or "\u{f00c}"  -- ✓
  elseif self.connection_state == ConnectionState.ERROR then
    return icons.error or "\u{f026}"  -- ⚠
  elseif self.connection_state == ConnectionState.CONNECTING then
    return icons.connecting or "\u{f110}"  --
  elseif self.connection_state == ConnectionState.DISCONNECTED then
    return icons.disconnected or "\u{f00d}"  -- ✗
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
    self.databases and #self.databases or 0
  )
end

-- Export ConnectionState with the class
ServerClass.ConnectionState = ConnectionState

return ServerClass
