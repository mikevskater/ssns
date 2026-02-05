---@class ServerConfig
---@field host string Server hostname or IP address
---@field instance string? SQL Server instance name (optional)
---@field port number? Port number (optional)
---@field database string? Default database name (optional)

---@class AuthConfig
---@field type string Authentication type: "windows", "sql", "none"
---@field username string? Username for SQL authentication (optional)
---@field password string? Password for SQL authentication (optional)

---@class OptionsConfig
---@field odbc_driver string? Specific ODBC driver name (SQL Server only)
---@field ssl boolean? Enable SSL connections (optional)
---@field timeout number? Connection timeout in seconds (optional)
---@field trust_server_certificate boolean? Bypass certificate validation (optional)

---@class ConnectionData
---@field name string Connection display name
---@field type string Database type: "sqlserver"|"mysql"|"postgres"|"sqlite"
---@field server ServerConfig Nested server details
---@field auth AuthConfig Nested authentication details
---@field options OptionsConfig? Nested connection options (optional)
---@field favorite boolean Whether to show in tree on startup
---@field auto_connect boolean Whether to auto-connect on startup

---@class ConnectionsFile
---@field version number File format version
---@field connections ConnectionData[] Array of saved connections

---@class Connections
---Manages persistent connection storage in JSON file
local Connections = {}

local JsonUtils = require('nvim-ssns.utils.json')
local FileIO = require('nvim-ssns.async.file_io')

-- Current file format version
local FILE_VERSION = 2

---Get the path to the connections JSON file
---@return string path Full path to connections.json
function Connections.get_file_path()
  local data_path = vim.fn.stdpath("data")
  local ssns_path = data_path .. "/ssns"
  return ssns_path .. "/connections.json"
end

---Ensure the ssns data directory exists
function Connections.ensure_directory()
  local data_path = vim.fn.stdpath("data")
  local ssns_path = data_path .. "/ssns"
  vim.fn.mkdir(ssns_path, "p")
end

---Load connections from JSON file
---@return ConnectionData[] connections Array of connection objects
function Connections.load()
  local path = Connections.get_file_path()

  -- Check if file exists
  if vim.fn.filereadable(path) ~= 1 then
    return {}
  end

  -- Read file content
  local lines = vim.fn.readfile(path)
  if #lines == 0 then
    return {}
  end

  local content = table.concat(lines, "\n")

  -- Parse JSON
  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or not data then
    vim.notify("SSNS: Failed to parse connections file", vim.log.levels.WARN)
    return {}
  end

  return data.connections or {}
end

---Save connections to JSON file
---@param connections ConnectionData[] Array of connection objects
---@return boolean success
function Connections.save(connections)
  Connections.ensure_directory()
  local path = Connections.get_file_path()

  local data = {
    version = FILE_VERSION,
    connections = connections,
  }

  -- Prettify using shared JsonUtils
  local lines = JsonUtils.prettify_lines(data)

  -- Write to file
  local write_ok = pcall(vim.fn.writefile, lines, path)
  if not write_ok then
    vim.notify("SSNS: Failed to write connections file", vim.log.levels.ERROR)
    return false
  end

  return true
end

---Validate a connection data object
---@param connection ConnectionData Connection data to validate
---@return boolean valid
---@return string? error_message
function Connections.validate(connection)
  -- Check required fields
  if not connection.name or connection.name == "" then
    return false, "Connection name is required"
  end

  if not connection.type or connection.type == "" then
    return false, "Database type is required"
  end

  -- Validate type is one of the supported types
  local valid_types = { sqlserver = true, mysql = true, postgres = true, sqlite = true }
  if not valid_types[connection.type] then
    return false, string.format("Invalid database type: %s", connection.type)
  end

  -- Check server config
  if not connection.server then
    return false, "Server configuration is required"
  end

  if not connection.server.host or connection.server.host == "" then
    return false, "Server host is required"
  end

  -- Check auth config
  if not connection.auth then
    return false, "Authentication configuration is required"
  end

  if not connection.auth.type then
    return false, "Authentication type is required"
  end

  -- Validate auth type
  local valid_auth_types = { windows = true, sql = true, none = true }
  if not valid_auth_types[connection.auth.type] then
    return false, string.format("Invalid authentication type: %s", connection.auth.type)
  end

  -- SQL auth requires username
  if connection.auth.type == "sql" then
    if not connection.auth.username or connection.auth.username == "" then
      return false, "Username is required for SQL authentication"
    end
  end

  return true, nil
end

---Find a connection by name
---@param name string Connection name
---@return ConnectionData? connection The connection or nil
function Connections.find(name)
  local connections = Connections.load()

  for _, conn in ipairs(connections) do
    if conn.name == name then
      return conn
    end
  end

  return nil
end

---Get all connections that should auto-connect
---@return ConnectionData[] connections Array of auto-connect connections
function Connections.get_auto_connect()
  local connections = Connections.load()
  local auto_connect = {}

  for _, conn in ipairs(connections) do
    if conn.auto_connect then
      table.insert(auto_connect, conn)
    end
  end

  return auto_connect
end

---Set favorite status for a connection
---@param name string Connection name
---@param favorite boolean New favorite state
---@return boolean success
function Connections.set_favorite(name, favorite)
  local connections = Connections.load()
  local found = false

  for i, conn in ipairs(connections) do
    if conn.name == name then
      connections[i].favorite = favorite
      found = true
      break
    end
  end

  if not found then
    vim.notify(string.format("SSNS: Connection '%s' not found", name), vim.log.levels.WARN)
    return false
  end

  return Connections.save(connections)
end

---Check if any connections exist in the file
---@return boolean has_connections
function Connections.has_connections()
  local connections = Connections.load()
  return #connections > 0
end

---Get connection count
---@return number count
function Connections.count()
  local connections = Connections.load()
  return #connections
end

---Generate a unique connection key for pooling/caching
---@param connection ConnectionData
---@return string key
function Connections.generate_connection_key(connection)
  if not connection then
    return "unknown"
  end

  local parts = { connection.type or "unknown" }

  -- Add server info (if available)
  local server = connection.server or {}
  if server.host then
    table.insert(parts, server.host)
  end
  if server.instance then
    table.insert(parts, server.instance)
  end
  if server.port then
    table.insert(parts, tostring(server.port))
  end
  if server.database then
    table.insert(parts, server.database)
  end

  -- Add auth type (if available)
  local auth = connection.auth or {}
  if auth.type then
    table.insert(parts, auth.type)
  end
  if auth.username then
    table.insert(parts, auth.username)
  end

  return table.concat(parts, ":")
end

---Create a copy of connection config with a different database
---@param connection ConnectionData Original connection config
---@param new_database string New database name
---@return ConnectionData modified Modified connection config
function Connections.with_database(connection, new_database)
  -- Deep copy the connection
  local modified = vim.deepcopy(connection)
  -- Ensure server table exists
  if not modified.server then
    modified.server = {}
  end
  modified.server.database = new_database
  return modified
end

-- ============================================================================
-- Async Methods
-- ============================================================================

---Load connections from JSON file asynchronously
---@param callback fun(connections: ConnectionData[], error: string?)
function Connections.load_async(callback)
  local FileIO = require('nvim-ssns.async.file_io')
  local path = Connections.get_file_path()

  -- Check if file exists first
  FileIO.exists_async(path, function(exists, _)
    if not exists then
      callback({}, nil)
      return
    end

    FileIO.read_json_async(path, function(data, err)
      if err then
        callback({}, "Failed to load connections: " .. err)
        return
      end

      callback(data and data.connections or {}, nil)
    end)
  end)
end

---Save connections to JSON file asynchronously
---@param connections ConnectionData[] Array of connection objects
---@param callback fun(success: boolean, error: string?)
function Connections.save_async(connections, callback)
  local FileIO = require('nvim-ssns.async.file_io')
  local path = Connections.get_file_path()
  local dir = vim.fn.fnamemodify(path, ":h")

  local data = {
    version = FILE_VERSION,
    connections = connections,
  }

  -- Prettify using shared JsonUtils
  local lines = JsonUtils.prettify_lines(data)
  local content = table.concat(lines, "\n")

  -- Ensure directory exists first
  FileIO.mkdir_async(dir, function(mkdir_success, mkdir_err)
    if not mkdir_success then
      callback(false, "Failed to create directory: " .. (mkdir_err or "unknown error"))
      return
    end

    FileIO.write_async(path, content, function(result)
      callback(result.success, result.error)
    end)
  end)
end

---Add a new connection asynchronously
---@param connection ConnectionData Connection data to add
---@param callback fun(success: boolean, error: string?)
function Connections.add_async(connection, callback)
  -- Validate connection synchronously (it's just data validation)
  local valid, err = Connections.validate(connection)
  if not valid then
    callback(false, err)
    return
  end

  Connections.load_async(function(connections, load_err)
    if load_err then
      callback(false, load_err)
      return
    end

    -- Check for duplicate names
    for _, conn in ipairs(connections) do
      if conn.name == connection.name then
        callback(false, string.format("Connection '%s' already exists", connection.name))
        return
      end
    end

    -- Add defaults
    connection.favorite = connection.favorite or false
    connection.auto_connect = connection.auto_connect or false

    table.insert(connections, connection)
    Connections.save_async(connections, callback)
  end)
end

---Remove a connection by name asynchronously
---@param name string Connection name to remove
---@param callback fun(success: boolean, error: string?)
function Connections.remove_async(name, callback)
  Connections.load_async(function(connections, load_err)
    if load_err then
      callback(false, load_err)
      return
    end

    local found = false
    for i, conn in ipairs(connections) do
      if conn.name == name then
        table.remove(connections, i)
        found = true
        break
      end
    end

    if not found then
      callback(false, string.format("Connection '%s' not found", name))
      return
    end

    Connections.save_async(connections, callback)
  end)
end

---Update an existing connection asynchronously
---@param name string Connection name to update
---@param connection ConnectionData New connection data
---@param callback fun(success: boolean, error: string?)
function Connections.update_async(name, connection, callback)
  -- Validate connection synchronously
  local valid, err = Connections.validate(connection)
  if not valid then
    callback(false, err)
    return
  end

  Connections.load_async(function(connections, load_err)
    if load_err then
      callback(false, load_err)
      return
    end

    local found = false
    for i, conn in ipairs(connections) do
      if conn.name == name then
        connections[i] = connection
        found = true
        break
      end
    end

    if not found then
      callback(false, string.format("Connection '%s' not found", name))
      return
    end

    Connections.save_async(connections, callback)
  end)
end

---Find a connection by name asynchronously
---@param name string Connection name
---@param callback fun(connection: ConnectionData?, error: string?)
function Connections.find_async(name, callback)
  Connections.load_async(function(connections, err)
    if err then
      callback(nil, err)
      return
    end

    for _, conn in ipairs(connections) do
      if conn.name == name then
        callback(conn, nil)
        return
      end
    end

    callback(nil, nil)
  end)
end

---Get all favorite connections asynchronously
---@param callback fun(favorites: ConnectionData[], error: string?)
function Connections.get_favorites_async(callback)
  Connections.load_async(function(connections, err)
    if err then
      callback({}, err)
      return
    end

    local favorites = {}
    for _, conn in ipairs(connections) do
      if conn.favorite or conn.auto_connect then
        table.insert(favorites, conn)
      end
    end

    callback(favorites, nil)
  end)
end

---Toggle favorite status for a connection asynchronously
---@param name string Connection name
---@param callback fun(success: boolean, new_state: boolean?, error: string?)
function Connections.toggle_favorite_async(name, callback)
  Connections.load_async(function(connections, load_err)
    if load_err then
      callback(false, nil, load_err)
      return
    end

    local found = false
    local new_state = false

    for i, conn in ipairs(connections) do
      if conn.name == name then
        connections[i].favorite = not conn.favorite
        new_state = connections[i].favorite
        found = true
        break
      end
    end

    if not found then
      callback(false, nil, string.format("Connection '%s' not found", name))
      return
    end

    Connections.save_async(connections, function(success, save_err)
      callback(success, new_state, save_err)
    end)
  end)
end

return Connections
