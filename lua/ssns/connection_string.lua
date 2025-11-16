---Connection String parser and builder
---Parses database connection strings into components and rebuilds them
---@class ConnectionString
local ConnectionString = {}

---Parse a connection string into components
---Based on vim-dadbod's db#url#parse logic
---@param connection_string string The connection string to parse
---@return table parsed {scheme, user, password, host, instance, database, port, path}
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

  return parsed
end

---Build a connection string from components
---@param components table {scheme, user, password, host, instance, database, port}
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
