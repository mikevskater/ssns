---@class Cache
---Global cache manager for SSNS
---Maintains the list of servers and provides lookup/management functions
local Cache = {}

---@type ServerClass[]
Cache.servers = {}

---@type table<string, ServerClass>
Cache.servers_by_name = {}

---Default TTL (Time To Live) in seconds for cached data
Cache.default_ttl = 300  -- 5 minutes

---Add a server to the cache
---@param server ServerClass The server to add
---@return boolean success True if added, false if already exists
function Cache.add_server(server)
  -- Check if server with this name already exists
  if Cache.servers_by_name[server.name] then
    return false
  end

  -- Add to array
  table.insert(Cache.servers, server)

  -- Add to lookup map
  Cache.servers_by_name[server.name] = server

  return true
end

---Remove a server from the cache
---@param server ServerClass|string The server object or server name
---@return boolean success True if removed, false if not found
function Cache.remove_server(server)
  local server_name

  if type(server) == "string" then
    server_name = server
    server = Cache.servers_by_name[server_name]
  else
    server_name = server.name
  end

  if not server then
    return false
  end

  -- Disconnect if connected
  if server.is_connected and server.is_connected() then
    server:disconnect()
  end

  -- Remove from lookup map
  Cache.servers_by_name[server_name] = nil

  -- Remove from array
  for i, s in ipairs(Cache.servers) do
    if s == server then
      table.remove(Cache.servers, i)
      return true
    end
  end

  return false
end

---Find a server by name
---@param server_name string
---@return ServerClass? server The server or nil if not found
function Cache.find_server(server_name)
  return Cache.servers_by_name[server_name]
end

---Find a database by server name and database name
---@param server_name string
---@param database_name string
---@return DbClass? database The database or nil if not found
function Cache.find_database(server_name, database_name)
  local server = Cache.find_server(server_name)
  if not server then
    return nil
  end

  return server:find_database(database_name)
end

---Find a schema by server, database, and schema names
---@param server_name string
---@param database_name string
---@param schema_name string
---@return SchemaClass? schema The schema or nil if not found
function Cache.find_schema(server_name, database_name, schema_name)
  local database = Cache.find_database(server_name, database_name)
  if not database then
    return nil
  end

  return database:find_schema(schema_name)
end

---Find a table by full path
---@param server_name string
---@param database_name string
---@param schema_name string
---@param table_name string
---@return TableClass? table The table or nil if not found
function Cache.find_table(server_name, database_name, schema_name, table_name)
  local schema = Cache.find_schema(server_name, database_name, schema_name)
  if not schema then
    return nil
  end

  return schema:find_table(table_name)
end

---Find an object by full path
---@param path string[] Array of path components [server, database, schema, object]
---@return BaseDbObject? object The found object or nil
function Cache.find_by_path(path)
  if #path == 0 then
    return nil
  end

  -- Start with server
  local server = Cache.find_server(path[1])
  if not server then
    return nil
  end

  if #path == 1 then
    return server
  end

  -- Use the server's find_by_path for the rest
  local remaining = {}
  for i = 2, #path do
    table.insert(remaining, path[i])
  end

  return server:find_by_path(remaining)
end

---Get all servers
---@return ServerClass[] servers Array of all servers
function Cache.get_all_servers()
  return Cache.servers
end

---Get count of servers in cache
---@return number count
function Cache.get_server_count()
  return #Cache.servers
end

---Check if cache is empty
---@return boolean empty
function Cache.is_empty()
  return #Cache.servers == 0
end

---Clear all servers from cache
function Cache.clear_all()
  -- Disconnect all servers
  for _, server in ipairs(Cache.servers) do
    if server.is_connected and server.is_connected() then
      server:disconnect()
    end
  end

  -- Clear arrays and maps
  Cache.servers = {}
  Cache.servers_by_name = {}
end

---Refresh all servers (reload databases)
function Cache.refresh_all()
  for _, server in ipairs(Cache.servers) do
    server:reload()
  end
end

---Refresh a specific server
---@param server_name string
---@return boolean success
function Cache.refresh_server(server_name)
  local server = Cache.find_server(server_name)
  if not server then
    return false
  end

  server:reload()
  return true
end

---Get all connected databases across all servers
---@return DbClass[] databases Array of connected databases
function Cache.get_connected_databases()
  local databases = {}

  for _, server in ipairs(Cache.servers) do
    if server:is_connected() then
      for _, db in ipairs(server:get_databases()) do
        if db.is_connected then
          table.insert(databases, db)
        end
      end
    end
  end

  return databases
end

---Get currently active database (the one marked as connected)
---@return DbClass? database The active database or nil
function Cache.get_active_database()
  for _, server in ipairs(Cache.servers) do
    if server:is_connected() then
      for _, db in ipairs(server:get_databases()) do
        if db.is_connected then
          return db
        end
      end
    end
  end

  return nil
end

---Set a database as active (disconnect all others)
---@param database DbClass
function Cache.set_active_database(database)
  -- Disconnect all other databases
  for _, server in ipairs(Cache.servers) do
    for _, db in ipairs(server:get_databases()) do
      db.is_connected = false
    end
  end

  -- Connect this database
  database.is_connected = true
end

---Load servers from user configuration
---@param config table Configuration table with connections
---@return ServerClass[] servers Created servers
---@return table<string, string> errors Map of failed connections to error messages
function Cache.load_from_config(config)
  if not config or not config.connections then
    return {}, {}
  end

  local Factory = require('ssns.factory')
  local servers, errors = Factory.create_servers_from_config(config.connections)

  -- Add all successfully created servers to cache
  for _, server in ipairs(servers) do
    Cache.add_server(server)
  end

  return servers, errors
end

---Check if a server name is already in use
---@param server_name string
---@return boolean exists
function Cache.server_exists(server_name)
  return Cache.servers_by_name[server_name] ~= nil
end

---Rename a server
---@param old_name string
---@param new_name string
---@return boolean success
---@return string? error_message
function Cache.rename_server(old_name, new_name)
  -- Check if new name already exists
  if Cache.server_exists(new_name) then
    return false, "Server with new name already exists"
  end

  local server = Cache.find_server(old_name)
  if not server then
    return false, "Server not found"
  end

  -- Update name
  Cache.servers_by_name[old_name] = nil
  server.name = new_name
  Cache.servers_by_name[new_name] = server

  return true, nil
end

---Get statistics about cached data
---@return table stats Statistics table
function Cache.get_stats()
  local stats = {
    server_count = #Cache.servers,
    connected_servers = 0,
    total_databases = 0,
    connected_databases = 0,
    servers = {},
  }

  for _, server in ipairs(Cache.servers) do
    local server_stats = {
      name = server.name,
      connected = server:is_connected(),
      db_type = server:get_db_type(),
      database_count = 0,
    }

    if server:is_connected() then
      stats.connected_servers = stats.connected_servers + 1
    end

    if server.is_loaded then
      server_stats.database_count = #server.children
      stats.total_databases = stats.total_databases + server_stats.database_count

      for _, db in ipairs(server:get_databases()) do
        if db.is_connected then
          stats.connected_databases = stats.connected_databases + 1
        end
      end
    end

    table.insert(stats.servers, server_stats)
  end

  return stats
end

---Debug: Print cache contents
function Cache.debug_print()
  print("=== SSNS Cache Contents ===")
  print(string.format("Servers: %d", #Cache.servers))

  for i, server in ipairs(Cache.servers) do
    print(string.format("  [%d] %s (%s) - %s", i, server.name, server:get_db_type() or "unknown", server.connection_state))

    if server.is_loaded and #server.children > 0 then
      print(string.format("      Databases: %d", #server.children))
      for _, db in ipairs(server.children) do
        local connected = db.is_connected and "✓" or ""
        print(string.format("        - %s %s", db.name, connected))
      end
    end
  end

  print("===========================")
end

---Export cache to a serializable format (for persistence)
---@return table data Serializable cache data
function Cache.export()
  local data = {
    servers = {},
  }

  for _, server in ipairs(Cache.servers) do
    table.insert(data.servers, {
      name = server.name,
      connection_string = server.connection_string,
      connection_state = server.connection_state,
    })
  end

  return data
end

---Import cache from serializable format (for persistence)
---@param data table Serialized cache data
---@return boolean success
function Cache.import(data)
  if not data or not data.servers then
    return false
  end

  Cache.clear_all()

  local Factory = require('ssns.factory')

  for _, server_data in ipairs(data.servers) do
    local server, err = Factory.create_server(server_data.name, server_data.connection_string)

    if server then
      Cache.add_server(server)
    end
  end

  return true
end

return Cache
