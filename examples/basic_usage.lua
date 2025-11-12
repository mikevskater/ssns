-- Example: Basic SSNS Usage
-- This file demonstrates how to use SSNS programmatically

-- Load SSNS
local ssns = require('ssns')

-- Setup with configuration
ssns.setup({
  connections = {
    -- SQL Server examples
    local_dev = "sqlserver://localhost/vim_dadbod_test",
    local_express = "sqlserver://localhost\\SQLEXPRESS/TestDB",
    remote_server = "sqlserver://user:password@192.168.1.100/ProductionDB",

    -- PostgreSQL example (for future)
    -- postgres_dev = "postgres://localhost:5432/mydb",

    -- MySQL example (for future)
    -- mysql_dev = "mysql://localhost:3306/mydb",
  },

  ui = {
    position = "left",
    width = 40,
    ssms_style = true,
    show_schema_prefix = true,
  },

  cache = {
    ttl = 300,  -- 5 minutes
  },
})

-- Get instances
local Cache = ssns.get_cache()
local Factory = ssns.get_factory()
local Config = ssns.get_config()

-- Example 1: List all servers
print("\n=== Example 1: List All Servers ===")
local servers = Cache.get_all_servers()
print(string.format("Total servers: %d", #servers))
for i, server in ipairs(servers) do
  print(string.format("  [%d] %s - %s", i, server.name, server:get_db_type()))
end

-- Example 2: Connect to a server and load databases
print("\n=== Example 2: Connect and Load Databases ===")
local server = Cache.find_server("local_dev")
if server then
  print(string.format("Found server: %s", server.name))

  local success, err = server:connect()
  if success then
    print("  ✓ Connected successfully")

    -- Load databases
    server:load()
    local databases = server:get_databases()
    print(string.format("  Databases: %d", #databases))

    for _, db in ipairs(databases) do
      print(string.format("    - %s", db.name))
    end
  else
    print(string.format("  ✗ Connection failed: %s", err))
  end
else
  print("Server 'local_dev' not found")
end

-- Example 3: Navigate the hierarchy
print("\n=== Example 3: Navigate Hierarchy ===")
local db = Cache.find_database("local_dev", "vim_dadbod_test")
if db then
  print(string.format("Found database: %s", db.name))

  -- Load schemas
  db:load()
  local schemas = db:get_schemas()
  print(string.format("  Schemas: %d", #schemas))

  for _, schema in ipairs(schemas) do
    print(string.format("    - %s", schema.name))

    -- Load tables in first schema
    if schema == schemas[1] then
      schema:load_tables()
      print(string.format("      Tables in %s:", schema.name))
      for _, table in ipairs(schema.tables or {}) do
        print(string.format("        • %s", table.name))
      end
    end
  end
end

-- Example 4: Create a server programmatically
print("\n=== Example 4: Create Server Programmatically ===")
local new_server, err = Factory.create_server("Test Server", "sqlserver://localhost/TestDB")
if new_server then
  print(string.format("Created server: %s (%s)", new_server.name, new_server:get_db_type()))

  -- Add to cache
  local added = Cache.add_server(new_server)
  print(string.format("  Added to cache: %s", tostring(added)))
else
  print(string.format("Failed to create server: %s", err))
end

-- Example 5: Generate SQL for a table
print("\n=== Example 5: Generate SQL ===")
local table = Cache.find_table("local_dev", "vim_dadbod_test", "dbo", "Employees")
if table then
  print(string.format("Found table: %s", table.name))

  -- Generate SELECT statement
  local select_sql = table:generate_select(10)
  print("\nSELECT statement:")
  print(select_sql)

  -- Generate INSERT statement
  local insert_sql = table:generate_insert()
  print("\nINSERT statement:")
  print(insert_sql)

  -- Load and display columns
  local columns = table:get_columns()
  print(string.format("\nColumns (%d):", #columns))
  for _, col in ipairs(columns) do
    print(string.format("  - %s", col:get_display_name()))
  end
else
  print("Table not found (ensure server is connected and database is loaded)")
end

-- Example 6: Cache statistics
print("\n=== Example 6: Cache Statistics ===")
local stats = Cache.get_stats()
print(string.format("Total Servers: %d", stats.server_count))
print(string.format("Connected Servers: %d", stats.connected_servers))
print(string.format("Total Databases: %d", stats.total_databases))
print(string.format("Connected Databases: %d", stats.connected_databases))

-- Example 7: Find by path
print("\n=== Example 7: Find by Path ===")
local obj = Cache.find_by_path({ "local_dev", "vim_dadbod_test", "dbo", "Employees" })
if obj then
  print(string.format("Found: %s", obj.name))
  print(string.format("Full path: %s", obj:get_full_path()))
  print(string.format("Type: %s", obj.__index.__name or "unknown"))
else
  print("Object not found in path")
end

-- Example 8: Export/Import cache
print("\n=== Example 8: Export/Import Cache ===")
local exported = Cache.export()
print(string.format("Exported %d servers", #exported.servers))
for _, server_data in ipairs(exported.servers) do
  print(string.format("  - %s: %s", server_data.name, server_data.connection_string))
end

-- Example 9: Validate connection string
print("\n=== Example 9: Validate Connection String ===")
local test_strings = {
  "sqlserver://localhost/TestDB",
  "postgres://localhost:5432/mydb",
  "invalid://connection",
  "",
}

for _, conn_str in ipairs(test_strings) do
  local valid, err = Factory.validate_connection_string(conn_str)
  if valid then
    print(string.format("  ✓ Valid: %s", conn_str))
  else
    print(string.format("  ✗ Invalid: %s - %s", conn_str, err))
  end
end

print("\n=== Examples Complete ===\n")
