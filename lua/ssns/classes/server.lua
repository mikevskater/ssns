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
---@field connection_config ConnectionData The database connection configuration
---@field connection_state string Current connection state
---@field adapter BaseAdapter Database-specific adapter
---@field connection any Active database connection object
---@field databases DbClass[]? Array of database objects
---@field error_message string? Error message if connection failed
---@field last_connected_at number? Timestamp of last successful connection
local ServerClass = setmetatable({}, { __index = BaseDbObject })
ServerClass.__index = ServerClass

---Create a new Server instance
---@param opts {name: string, connection_config: ConnectionData}
---@return ServerClass
function ServerClass.new(opts)
  -- Create base object
  local self = setmetatable(BaseDbObject.new({
    name = opts.name,
    parent = nil,  -- Server is root level
  }), ServerClass)

  self.connection_config = opts.connection_config
  self.connection_state = ConnectionState.DISCONNECTED
  self.connection = nil
  self.databases = nil
  self.error_message = nil
  self.last_connected_at = nil

  -- Create adapter from connection config type
  local AdapterFactory = require('ssns.adapters.factory')
  local db_type = self.connection_config and self.connection_config.type

  if not db_type then
    self.error_message = "No database type specified in connection config"
    self.connection_state = ConnectionState.ERROR
    self.adapter = nil
  else
    local adapter, err = AdapterFactory.create_adapter_for_type(db_type, self.connection_config)

    if not adapter then
      self.error_message = err or "Failed to create adapter"
      self.connection_state = ConnectionState.ERROR
    end

    self.adapter = adapter
  end

  -- Set object type for highlighting
  self.object_type = "server"

  return self
end

---Get the database type for this server
---@return string? db_type
function ServerClass:get_db_type()
  return self.connection_config and self.connection_config.type or nil
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
  local success, err = ConnectionModule.test(self.connection_config)

  if not success then
    self.connection_state = ConnectionState.ERROR
    self.error_message = err or "Connection test failed"
    return false, self.error_message
  end

  -- Create or get connection from pool
  self.connection = ConnectionModule.get_or_create(self.connection_config)

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

      -- Eagerly load database schemas if configured
      -- This will load schema names for all databases immediately after connecting
      -- Disabled by default to avoid 100s of queries on large servers
      local Config = require('ssns.config')
      local config = Config.get()
      if config.completion and config.completion.eager_load and load_success and self.databases then
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
  ConnectionModule.close(self.connection_config)

  self.connection = nil
  self.connection_state = ConnectionState.DISCONNECTED
  self.last_connected_at = nil

  -- Clear loaded databases (will need to reconnect and reload)
  self.databases = nil
  self.is_loaded = false
end

---Toggle connection state (connect if disconnected, disconnect if connected)
---Uses async for non-blocking UI when connecting
---@param callback fun(success: boolean, error: string?)? Optional callback when complete
function ServerClass:toggle_connection(callback)
  if self:is_connected() then
    self:disconnect()
    if callback then
      vim.schedule(function()
        callback(true, nil)
      end)
    end
  else
    self:connect_async({
      on_complete = function(success, err)
        if callback then
          callback(success, err)
        end
      end,
    })
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
  return ConnectionModule.test(self.connection_config)
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
  success, results = pcall(self.adapter.execute, self.adapter, self.connection_config, query)
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
  Connection.invalidate_cache(self.connection_config)

  -- Clear databases array and reset loaded state
  self.databases = nil
  self.is_loaded = false
  local load_success = self:load()

  -- Eagerly load metadata for completion if enabled
  -- WARNING: On servers with many databases, this will trigger many queries
  -- Set completion.eager_load = false (default) for lazy loading
  local Config = require('ssns.config')
  local config = Config.get()
  if config.completion and config.completion.eager_load and load_success and self.databases then
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
    return icons.connected or "\u{f00c}"  -- checkmark
  elseif self.connection_state == ConnectionState.ERROR then
    return icons.error or "\u{f026}"  -- warning
  elseif self.connection_state == ConnectionState.CONNECTING then
    return icons.connecting or "\u{f110}"  -- spinner
  elseif self.connection_state == ConnectionState.DISCONNECTED then
    return icons.disconnected or "\u{f00d}"  -- x
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

---Get a copy of connection config with a different database
---@param new_database string The new database name
---@return ConnectionData modified Modified connection config
function ServerClass:get_connection_config_for_database(new_database)
  local Connections = require('ssns.connections')
  return Connections.with_database(self.connection_config, new_database)
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

-- ============================================================================
-- Async Methods
-- ============================================================================

---@class ServerRPCAsyncOpts
---@field timeout_ms number? Timeout in milliseconds (default: 30000)
---@field on_complete fun(success: boolean, error: string?)? Completion callback

---Connect to the database server using true non-blocking RPC async
---This method does NOT block the UI - the connection test runs in Node.js
---and calls back when complete.
---@param opts ServerRPCAsyncOpts? Options
---@return string callback_id Callback ID for tracking/cancellation
function ServerClass:connect_async(opts)
  opts = opts or {}
  local Connection = require('ssns.connection')

  -- Already connected - return immediately via callback
  if self.connection_state == ConnectionState.CONNECTED then
    if opts.on_complete then
      vim.schedule(function()
        opts.on_complete(true, nil)
      end)
    end
    return "already_connected"
  end

  -- No adapter available
  if not self.adapter then
    if opts.on_complete then
      vim.schedule(function()
        opts.on_complete(false, self.error_message or "No adapter available")
      end)
    end
    return "no_adapter"
  end

  -- Set state to connecting
  self.connection_state = ConnectionState.CONNECTING
  self.error_message = nil

  -- Use true async RPC to test connection (SELECT 1 AS test)
  local test_query = "SELECT 1 AS test"
  local server_self = self  -- Capture self for callback

  return Connection.execute_rpc_async(self.connection_config, test_query, {
    timeout_ms = opts.timeout_ms or 30000,
    on_complete = function(result, err)
      if err then
        server_self.connection_state = ConnectionState.ERROR
        server_self.error_message = err
        if opts.on_complete then
          opts.on_complete(false, err)
        end
        return
      end

      if not result or not result.success then
        local error_msg = (result and result.error and result.error.message) or "Connection test failed"
        server_self.connection_state = ConnectionState.ERROR
        server_self.error_message = error_msg
        if opts.on_complete then
          opts.on_complete(false, error_msg)
        end
        return
      end

      -- Connection successful - create/get connection from pool
      server_self.connection = Connection.get_or_create(server_self.connection_config)
      server_self.connection_state = ConnectionState.CONNECTED
      server_self.last_connected_at = os.time()

      if opts.on_complete then
        opts.on_complete(true, nil)
      end
    end,
    on_error = function(err)
      server_self.connection_state = ConnectionState.ERROR
      server_self.error_message = err
      if opts.on_complete then
        opts.on_complete(false, err)
      end
    end,
  })
end

---Load databases from the server using true non-blocking RPC async
---This method does NOT block the UI - the query runs in Node.js
---and calls back when complete.
---NOTE: Server must already be connected. Use connect_and_load_async() for combined operation.
---@param opts ServerRPCAsyncOpts? Options
---@return string callback_id Callback ID for tracking/cancellation
function ServerClass:load_async(opts)
  opts = opts or {}
  local Connection = require('ssns.connection')

  -- Already loaded - return immediately via callback
  if self.is_loaded then
    if opts.on_complete then
      vim.schedule(function()
        opts.on_complete(true, nil)
      end)
    end
    return "already_loaded"
  end

  -- Must be connected to load databases
  if not self:is_connected() then
    if opts.on_complete then
      vim.schedule(function()
        opts.on_complete(false, "Server not connected. Call connect_async() first or use connect_and_load_async()")
      end)
    end
    return "not_connected"
  end

  -- No adapter available
  if not self.adapter then
    if opts.on_complete then
      vim.schedule(function()
        opts.on_complete(false, self.error_message or "No adapter available")
      end)
    end
    return "no_adapter"
  end

  -- Get the databases query from adapter (sync - just builds SQL string)
  local query_success, query = pcall(self.adapter.get_databases_query, self.adapter)
  if not query_success then
    local err_msg = "Failed to get databases query: " .. tostring(query)
    self.error_message = err_msg
    if opts.on_complete then
      vim.schedule(function()
        opts.on_complete(false, err_msg)
      end)
    end
    return "query_error"
  end

  -- Initialize databases array
  self.databases = {}

  local server_self = self  -- Capture self for callback

  -- Execute via true async RPC (non-blocking)
  return Connection.execute_rpc_async(self.connection_config, query, {
    timeout_ms = opts.timeout_ms or 30000,
    on_complete = function(result, err)
      if err then
        server_self.error_message = err
        if opts.on_complete then
          opts.on_complete(false, err)
        end
        return
      end

      if not result or not result.success then
        local error_msg = (result and result.error and result.error.message) or "Failed to load databases"
        server_self.error_message = error_msg
        if opts.on_complete then
          opts.on_complete(false, error_msg)
        end
        return
      end

      -- Parse databases from result
      local parse_success, databases = pcall(server_self.adapter.parse_databases, server_self.adapter, result)
      if not parse_success then
        local error_msg = "Failed to parse databases: " .. tostring(databases)
        server_self.error_message = error_msg
        if opts.on_complete then
          opts.on_complete(false, error_msg)
        end
        return
      end

      -- Create database objects
      local DbClass = require('ssns.classes.database')
      for _, db_data in ipairs(databases) do
        local db = DbClass.new({
          name = db_data.name,
          parent = server_self,
        })
        table.insert(server_self.databases, db)
      end

      server_self.is_loaded = true

      if opts.on_complete then
        opts.on_complete(true, nil)
      end
    end,
    on_error = function(err)
      server_self.error_message = err
      if opts.on_complete then
        opts.on_complete(false, err)
      end
    end,
  })
end

---Connect and load databases using true non-blocking RPC async (combined operation)
---This method does NOT block the UI - both connection test and database load run in Node.js
---and call back when complete.
---@param opts ServerRPCAsyncOpts? Options
---@return string callback_id Callback ID for tracking/cancellation
function ServerClass:connect_and_load_async(opts)
  opts = opts or {}

  -- Already connected and loaded - return immediately via callback
  if self:is_connected() and self.is_loaded then
    if opts.on_complete then
      vim.schedule(function()
        opts.on_complete(true, nil)
      end)
    end
    return "already_complete"
  end

  -- Already connected but not loaded - just load
  if self:is_connected() then
    return self:load_async(opts)
  end

  -- Not connected - connect first, then load
  local server_self = self  -- Capture self for callback

  return self:connect_async({
    timeout_ms = opts.timeout_ms,
    on_complete = function(success, err)
      if not success then
        if opts.on_complete then
          opts.on_complete(false, err)
        end
        return
      end

      -- Connection successful - now load databases
      server_self:load_async({
        timeout_ms = opts.timeout_ms,
        on_complete = opts.on_complete,
      })
    end,
  })
end

-- Export ConnectionState with the class
ServerClass.ConnectionState = ConnectionState

return ServerClass
