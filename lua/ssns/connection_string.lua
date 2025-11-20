---Connection String parser and builder
---Parses database connection strings into components and rebuilds them
---@class ConnectionString
local ConnectionString = {}

---Cached ODBC driver (so we don't query every time)
---@type string?
local cached_odbc_driver = nil

---Get the best available ODBC driver for SQL Server
---@return string? driver_name The best ODBC driver name, or nil if none found
function ConnectionString.get_best_odbc_driver()
  -- Return cached value if available
  if cached_odbc_driver then
    return cached_odbc_driver
  end

  -- Preferred drivers in order
  local preferred_drivers = {
    'ODBC Driver 18 for SQL Server',
    'ODBC Driver 17 for SQL Server',
    'ODBC Driver 13 for SQL Server',
    'ODBC Driver 11 for SQL Server',
    'SQL Server Native Client 11.0',
    'SQL Server'
  }

  -- Query available drivers using PowerShell
  local powershell_cmd = [[powershell -NoProfile -Command "Get-OdbcDriver | Where-Object {$_.Name -like '*SQL Server*'} | Select-Object -ExpandProperty Name"]]

  local handle = io.popen(powershell_cmd)
  if not handle then
    -- Fallback to default if PowerShell fails
    cached_odbc_driver = 'ODBC Driver 17 for SQL Server'
    return cached_odbc_driver
  end

  local available_drivers = {}
  for line in handle:lines() do
    local trimmed = line:match("^%s*(.-)%s*$")  -- Trim whitespace
    if trimmed and trimmed ~= "" then
      table.insert(available_drivers, trimmed)
    end
  end
  handle:close()

  -- Find the best match from preferred list
  for _, preferred in ipairs(preferred_drivers) do
    for _, available in ipairs(available_drivers) do
      if available == preferred then
        cached_odbc_driver = preferred
        return cached_odbc_driver
      end
    end
  end

  -- If no preferred driver found, use the first available one
  if #available_drivers > 0 then
    cached_odbc_driver = available_drivers[1]
    return cached_odbc_driver
  end

  -- No drivers found, use default fallback
  cached_odbc_driver = 'ODBC Driver 17 for SQL Server'
  return cached_odbc_driver
end

---Parse a connection string into components
---Based on vim-dadbod's db#url#parse logic
---@param connection_string string The connection string to parse
---@return table parsed {scheme, user, password, host, instance, database, port, path, odbc_driver}
function ConnectionString.parse(connection_string)
  local parsed = {
    scheme = nil,
    user = nil,
    password = nil,
    host = nil,
    instance = nil,
    database = nil,
    port = nil,
    path = nil,
    odbc_driver = nil,
    original = connection_string
  }

  -- SQL Server special case: host can contain backslash (host\instance)
  -- Need to handle this BEFORE splitting user:password@host
  -- Pattern needs to differentiate between:
  --   user:pass@host  (has @)
  --   host\instance   (no @)

  -- First, extract scheme
  local scheme, rest = connection_string:match("^([%w%.%+%-]+)://(.*)$")
  if not scheme then
    return parsed
  end
  parsed.scheme = scheme

  -- NORMALIZE: Convert all backslashes to forward slashes for parsing
  -- The builder will output the correct format (backslash for SQL Server instances)
  rest = rest:gsub("\\", "/")

  -- Check if there's auth (user:password@)
  local auth_part, server_part
  if rest:match("@") then
    -- Has authentication
    auth_part, server_part = rest:match("^([^@]+)@(.*)$")
    if auth_part then
      local u, p = auth_part:match("^([^:]*):?(.*)$")
      parsed.user = u ~= "" and u or nil
      parsed.password = p ~= "" and p or nil
    end
  else
    -- No authentication
    server_part = rest
  end

  -- Parse server_part: host[/instance][:port][/database]
  -- Now everything uses forward slash since we normalized above
  --
  -- Strategy:
  -- - Split at LAST "/" to separate database path
  -- - Everything before last "/" is: host[/instance][:port]
  -- - If only 1 "/", check if it has ":" after it (means instance with port)

  local slash_positions = {}
  local pos = 1
  while true do
    local found = server_part:find("/", pos, true)
    if not found then break end
    table.insert(slash_positions, found)
    pos = found + 1
  end

  local host_port, path
  if #slash_positions == 0 then
    -- No slashes at all
    host_port = server_part
    path = nil
  elseif #slash_positions == 1 then
    -- Single slash - is it instance or database?
    -- If what comes after contains ":", it's instance with port
    -- Otherwise, for SQL Server assume instance, for others assume database
    local before_slash = server_part:sub(1, slash_positions[1] - 1)
    local after_slash = server_part:sub(slash_positions[1] + 1)

    if after_slash:match(":") then
      -- Has port, so it's instance/port pattern
      host_port = before_slash .. "/" .. after_slash
      path = nil
    elseif parsed.scheme == "sqlserver" or parsed.scheme == "mssql" then
      -- SQL Server: assume instance
      host_port = before_slash .. "/" .. after_slash
      path = nil
    else
      -- Other databases: assume database
      host_port = before_slash
      path = "/" .. after_slash
    end
  else
    -- Multiple slashes: last one is database separator
    local last_slash_pos = slash_positions[#slash_positions]
    host_port = server_part:sub(1, last_slash_pos - 1)
    path = server_part:sub(last_slash_pos)
  end

  -- Extract port if present (look for :digits at the end)
  local host_instance, port = host_port:match("^(.+):(%d+)$")
  if port then
    parsed.port = tonumber(port)
    host_port = host_instance
  end

  -- Now extract instance from host (separated by /)
  -- Since we normalized, everything uses forward slash now
  parsed.host = host_port
  if parsed.host and parsed.host:match("/") then
    local h, inst = parsed.host:match("^([^/]+)/(.+)$")
    if h and inst then
      parsed.host = h
      parsed.instance = inst
    end
  end

  -- Handle path/database
  if path and path:match("^/") then
    parsed.path = path
    -- Extract database from path (remove leading /)
    parsed.database = path:match("^/([^/?#]*)")
  end

  -- For SQL Server without authentication, detect best ODBC driver
  if parsed.scheme == "sqlserver" or parsed.scheme == "mssql" then
    if not parsed.user then
      -- Windows authentication - get best ODBC driver
      parsed.odbc_driver = ConnectionString.get_best_odbc_driver()
    end
  end

  return parsed
end

---Build a connection string from components
---@param components table {scheme, user, password, host, instance, database, port, odbc_driver}
---@return string connection_string
function ConnectionString.build(components)
  local parts = {}

  -- Scheme
  table.insert(parts, components.scheme or "sqlserver")
  table.insert(parts, "://")

  -- Auth
  if components.user then
    table.insert(parts, components.user)
    if components.password then
      table.insert(parts, ":")
      table.insert(parts, components.password)
    end
    table.insert(parts, "@")
  end

  -- Host
  table.insert(parts, components.host or "localhost")

  -- Instance (SQL Server specific)
  if components.instance then
    table.insert(parts, "\\")
    table.insert(parts, components.instance)
  end

  -- Port
  if components.port then
    table.insert(parts, ":")
    table.insert(parts, tostring(components.port))
  end

  -- Database
  if components.database then
    table.insert(parts, "/")
    table.insert(parts, components.database)
  end

  -- ODBC driver (as query parameter for SQL Server Windows auth)
  if components.odbc_driver then
    -- URL-encode the driver name (replace spaces with %20)
    local encoded_driver = components.odbc_driver:gsub(" ", "%%20")
    table.insert(parts, "?driver=")
    table.insert(parts, encoded_driver)
  end

  return table.concat(parts)
end

---Create a new connection string with a different database
---@param connection_string string Original connection string
---@param new_database string New database name
---@return string new_connection_string
function ConnectionString.with_database(connection_string, new_database)
  local parsed = ConnectionString.parse(connection_string)
  parsed.database = new_database
  return ConnectionString.build(parsed)
end

---Get the database from a connection string
---@param connection_string string
---@return string? database
function ConnectionString.get_database(connection_string)
  local parsed = ConnectionString.parse(connection_string)
  return parsed.database
end

return ConnectionString
