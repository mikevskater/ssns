---@class Cache
---Global cache manager for SSNS
---Maintains the list of servers and provides lookup/management functions
local Cache = {}

---@type ServerClass[]
Cache.servers = {}

---@type table<string, ServerClass>
Cache.servers_by_name = {}

---Buffer-scoped cache for temp tables and CTEs (per query buffer)
---@type table<number, table>
Cache.buffer_cache = {}

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

---Find or create a server
---@param server_name string Server name
---@param connection_config ConnectionData Connection configuration
---@return ServerClass? server The server or nil if creation failed
---@return string? error_message Error message if creation failed
function Cache.find_or_create_server(server_name, connection_config)
  -- Check if server already exists
  local existing = Cache.find_server(server_name)
  if existing then
    return existing, nil
  end

  -- Create new server
  local Factory = require('ssns.factory')
  local server, err = Factory.create_server(server_name, connection_config)

  if not server then
    return nil, err
  end

  -- Add to cache
  Cache.add_server(server)

  return server, nil
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

---Load servers from user configuration (config.connections table)
---@param config SsnsConfig User configuration
---@return ServerClass[] servers Created servers
---@return table<string, string> errors Map of failed connections to error messages
function Cache.load_from_config(config)
  local Factory = require('ssns.factory')

  -- Check if config has connections defined
  if not config or not config.connections then
    return {}, {}
  end

  local servers = {}
  local errors = {}

  -- config.connections can be either:
  -- 1. Old format: { name = "connection_string" } (deprecated, will be converted)
  -- 2. New format: { name = ConnectionData } (structured data)
  for name, conn_data in pairs(config.connections) do
    -- Skip if server with this name already exists
    if Cache.server_exists(name) then
      goto continue
    end

    -- Handle old connection string format (deprecated)
    if type(conn_data) == "string" then
      errors[name] = "Connection string format is deprecated. Please use structured ConnectionData format."
      goto continue
    end

    -- Ensure name is set in the connection data
    if type(conn_data) == "table" then
      conn_data.name = conn_data.name or name

      local server, err = Factory.create_server(name, conn_data)

      if server then
        Cache.add_server(server)
        table.insert(servers, server)
      else
        errors[name] = err or "Unknown error"
      end
    end

    ::continue::
  end

  return servers, errors
end

---Load servers from connections JSON file
---@param auto_connect_only boolean? Only load connections with auto_connect=true
---@return ServerClass[] servers Created servers
---@return table<string, string> errors Map of failed connections to error messages
function Cache.load_from_connections_file(auto_connect_only)
  local Connections = require('ssns.connections')
  local Factory = require('ssns.factory')

  local connections
  if auto_connect_only then
    connections = Connections.get_auto_connect()
  else
    connections = Connections.load()
  end

  if #connections == 0 then
    return {}, {}
  end

  local servers = {}
  local errors = {}

  for _, conn in ipairs(connections) do
    -- Skip if server with this name already exists
    if Cache.server_exists(conn.name) then
      goto continue
    end

    -- Pass the entire connection config (not a connection_string field)
    local server, err = Factory.create_server(conn.name, conn)

    if server then
      Cache.add_server(server)
      table.insert(servers, server)
    else
      errors[conn.name] = err or "Unknown error"
    end

    ::continue::
  end

  return servers, errors
end

---Add a server from a ConnectionData object
---@param connection_data ConnectionData Connection data with all structured fields
---@return ServerClass? server The created server or nil
---@return string? error Error message if failed
function Cache.add_server_from_connection(connection_data)
  if not connection_data or not connection_data.name then
    return nil, "Invalid connection data: missing name"
  end

  if not connection_data.type then
    return nil, "Invalid connection data: missing database type"
  end

  if not connection_data.server or not connection_data.server.host then
    return nil, "Invalid connection data: missing server host"
  end

  -- Check if server already exists
  if Cache.server_exists(connection_data.name) then
    return nil, string.format("Server '%s' already exists in tree", connection_data.name)
  end

  local Factory = require('ssns.factory')
  local server, err = Factory.create_server(connection_data.name, connection_data)

  if not server then
    return nil, err or "Failed to create server"
  end

  Cache.add_server(server)
  return server, nil
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
      local databases = server:get_databases()
      server_stats.database_count = #databases
      stats.total_databases = stats.total_databases + server_stats.database_count

      for _, db in ipairs(databases) do
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

    local databases = server:get_databases()
    if server.is_loaded and #databases > 0 then
      print(string.format("      Databases: %d", #databases))
      for _, db in ipairs(databases) do
        local connected = db.is_connected and "[connected]" or ""
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
      connection_config = server.connection_config,
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
    local server, _ = Factory.create_server(server_data.name, server_data.connection_config)

    if server then
      Cache.add_server(server)
    end
  end

  return true
end

---Get temp tables for current buffer and GO chunk
---Returns temp tables visible at the current cursor position
---@param bufnr number Buffer number
---@param cursor_line number? Current line (optional, for chunk detection)
---@return table<string, table> temp_tables Map of temp table name -> TempTableClass
function Cache.get_buffer_temp_tables(bufnr, cursor_line)
  -- Get buffer cache
  local buf_cache = Cache.buffer_cache[bufnr]
  if not buf_cache then
    return {}
  end

  -- If no cursor_line, return all temp tables
  if not cursor_line then
    return buf_cache.temp_tables or {}
  end

  -- Find which GO chunk the cursor is in
  -- For now, just return all temp tables (chunk-based filtering can be added later)
  -- Local temps are cleared at GO boundaries by clear_local_temps_at_go()
  return buf_cache.temp_tables or {}
end

---Add temp table to buffer cache
---@param bufnr number Buffer number
---@param temp_table table TempTableClass object
---@param chunk_index number GO chunk index
function Cache.add_buffer_temp_table(bufnr, temp_table, chunk_index)
  -- Initialize buffer cache if needed
  if not Cache.buffer_cache[bufnr] then
    Cache.buffer_cache[bufnr] = {
      temp_tables = {},
      go_chunks = {},
      last_go_line = 0,
    }
  end

  -- Add to buffer cache
  Cache.buffer_cache[bufnr].temp_tables[temp_table.name] = temp_table

  -- Track in chunk
  if not Cache.buffer_cache[bufnr].go_chunks[chunk_index] then
    Cache.buffer_cache[bufnr].go_chunks[chunk_index] = { temp_tables = {} }
  end

  Cache.buffer_cache[bufnr].go_chunks[chunk_index].temp_tables[temp_table.name] = temp_table
end

---Clear local temp tables at GO boundary
---Removes all local temp tables (#temp, not ##temp)
---@param bufnr number Buffer number
---@param go_line number Line number of GO statement
function Cache.clear_local_temps_at_go(bufnr, go_line)
  -- Get buffer cache
  local buf_cache = Cache.buffer_cache[bufnr]
  if not buf_cache then
    return
  end

  -- Remove all local temp tables (#temp, not ##temp)
  for name, temp_table in pairs(buf_cache.temp_tables) do
    if temp_table.type == "local" then
      buf_cache.temp_tables[name] = nil
    end
  end

  -- Update last_go_line
  buf_cache.last_go_line = go_line
end

---Clear all buffer cache on buffer close
---@param bufnr number Buffer number
function Cache.clear_buffer_cache(bufnr)
  Cache.buffer_cache[bufnr] = nil
end

-- Setup autocmd to clear buffer cache on buffer close
vim.api.nvim_create_autocmd("BufDelete", {
  callback = function(args)
    Cache.clear_buffer_cache(args.buf)
  end,
})

return Cache
