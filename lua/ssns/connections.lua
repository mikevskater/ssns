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

  -- Encode to JSON with pretty printing
  local ok, json = pcall(vim.fn.json_encode, data)
  if not ok then
    vim.notify("SSNS: Failed to encode connections to JSON", vim.log.levels.ERROR)
    return false
  end

  -- Pretty print the JSON for readability
  local pretty_json = Connections._pretty_json(json)

  -- Split into lines for proper file writing (avoids Windows line ending issues)
  local lines = vim.split(pretty_json, '\n')

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

---Add a new connection
---@param connection ConnectionData Connection data to add
---@return boolean success
function Connections.add(connection)
  -- Validate connection
  local valid, err = Connections.validate(connection)
  if not valid then
    vim.notify("SSNS: " .. err, vim.log.levels.ERROR)
    return false
  end

  local connections = Connections.load()

  -- Check for duplicate names
  for _, conn in ipairs(connections) do
    if conn.name == connection.name then
      vim.notify(string.format("SSNS: Connection '%s' already exists", connection.name), vim.log.levels.ERROR)
      return false
    end
  end

  -- Add defaults
  connection.favorite = connection.favorite or false
  connection.auto_connect = connection.auto_connect or false

  table.insert(connections, connection)
  return Connections.save(connections)
end

---Remove a connection by name
---@param name string Connection name to remove
---@return boolean success
function Connections.remove(name)
  local connections = Connections.load()
  local found = false

  for i, conn in ipairs(connections) do
    if conn.name == name then
      table.remove(connections, i)
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

---Update an existing connection
---@param name string Connection name to update
---@param connection ConnectionData New connection data
---@return boolean success
function Connections.update(name, connection)
  -- Validate connection
  local valid, err = Connections.validate(connection)
  if not valid then
    vim.notify("SSNS: " .. err, vim.log.levels.ERROR)
    return false
  end

  local connections = Connections.load()
  local found = false

  for i, conn in ipairs(connections) do
    if conn.name == name then
      connections[i] = connection
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

---Get all favorite connections (includes auto_connect since those imply favorite)
---@return ConnectionData[] connections Array of favorite connections
function Connections.get_favorites()
  local connections = Connections.load()
  local favorites = {}

  for _, conn in ipairs(connections) do
    if conn.favorite or conn.auto_connect then
      table.insert(favorites, conn)
    end
  end

  return favorites
end

---Toggle favorite status for a connection
---@param name string Connection name
---@return boolean success
---@return boolean? new_state The new favorite state (if successful)
function Connections.toggle_favorite(name)
  local connections = Connections.load()
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
    vim.notify(string.format("SSNS: Connection '%s' not found", name), vim.log.levels.WARN)
    return false, nil
  end

  local success = Connections.save(connections)
  return success, new_state
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
  local parts = { connection.type }

  -- Add server info
  table.insert(parts, connection.server.host)
  if connection.server.instance then
    table.insert(parts, connection.server.instance)
  end
  if connection.server.port then
    table.insert(parts, tostring(connection.server.port))
  end
  if connection.server.database then
    table.insert(parts, connection.server.database)
  end

  -- Add auth type
  table.insert(parts, connection.auth.type)
  if connection.auth.username then
    table.insert(parts, connection.auth.username)
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
  modified.server.database = new_database
  return modified
end

---Pretty print JSON with indentation
---@param json string JSON string
---@return string pretty_json Formatted JSON
function Connections._pretty_json(json)
  -- Simple pretty printer for our connection structure
  -- Handles nested objects with 2-space indentation
  local result = {}
  local indent = 0
  local in_string = false
  local i = 1

  while i <= #json do
    local char = json:sub(i, i)

    if char == '"' and json:sub(i - 1, i - 1) ~= '\\' then
      in_string = not in_string
      table.insert(result, char)
    elseif not in_string then
      if char == '{' or char == '[' then
        table.insert(result, char)
        indent = indent + 1
        table.insert(result, '\n' .. string.rep('  ', indent))
      elseif char == '}' or char == ']' then
        indent = indent - 1
        table.insert(result, '\n' .. string.rep('  ', indent))
        table.insert(result, char)
      elseif char == ',' then
        table.insert(result, char)
        table.insert(result, '\n' .. string.rep('  ', indent))
      elseif char == ':' then
        table.insert(result, ': ')
      elseif char ~= ' ' and char ~= '\n' and char ~= '\t' then
        table.insert(result, char)
      end
    else
      table.insert(result, char)
    end

    i = i + 1
  end

  return table.concat(result)
end

return Connections
