-- Example: Testing SSNS Connection and Query Execution
-- This file demonstrates real database connections using vim-dadbod

-- NOTE: This requires vim-dadbod to be installed and your local database servers running

local ssns = require('ssns')

-- Setup SSNS with your local connections
ssns.setup({
  connections = {
    -- Your local SQL Server instance
    test_sqlserver = "sqlserver://.\\SQLEXPRESS/master",

    -- Your local MySQL instance (uncomment to test)
    -- test_mysql = "mysql://root:password@localhost:3306/mysql",
  },
})

local Cache = ssns.get_cache()
local Connection = require('ssns.connection')

print("\n=== SSNS Connection Test ===\n")

-- Test 1: Check if vim-dadbod is available
print("Test 1: Check vim-dadbod availability")
local has_dadbod = Connection.is_dadbod_available()
print(string.format("  vim-dadbod available: %s", tostring(has_dadbod)))

if not has_dadbod then
  print("\n❌ vim-dadbod is not installed. Please install it first:")
  print("  Plug 'tpope/vim-dadbod'")
  return
end

-- Test 2: Test connection
print("\nTest 2: Test connection to SQL Server")
local test_conn = "sqlserver://.\\SQLEXPRESS/master"
local success, err = Connection.test(test_conn)
if success then
  print("  ✓ Connection test successful")
else
  print(string.format("  ✗ Connection test failed: %s", err))
  print("\n  Make sure you have:")
  print("    1. SQL Server Express running (SQLEXPRESS instance)")
  print("    2. Proper authentication configured (Windows Authentication)")
  print("    3. vim-dadbod installed and working")
  return
end

-- Test 3: Execute a simple query
print("\nTest 3: Execute simple query")
local results, query_err = Connection.execute_sync(test_conn, "SELECT 1 AS test_column")
if query_err then
  print(string.format("  ✗ Query failed: %s", query_err))
else
  print(string.format("  ✓ Query successful, got %d results", #results))
  if #results > 0 then
    print("  Result:")
    for k, v in pairs(results[1]) do
      print(string.format("    %s = %s", k, v))
    end
  end
end

-- Test 4: Connect via ServerClass
print("\nTest 4: Connect via ServerClass")
local server = Cache.find_server("test_sqlserver")
if server then
  print(string.format("  Found server: %s", server.name))

  local conn_success, conn_err = server:connect()
  if conn_success then
    print("  ✓ Connected successfully")
    print(string.format("    State: %s", server.connection_state))
    print(string.format("    DB Type: %s", server:get_db_type()))
  else
    print(string.format("  ✗ Connection failed: %s", conn_err))
    return
  end
else
  print("  ✗ Server not found in cache")
  return
end

-- Test 5: Load databases
print("\nTest 5: Load databases from server")
local load_success = server:load()
if load_success then
  local databases = server:get_databases()
  print(string.format("  ✓ Loaded %d database(s)", #databases))

  for i, db in ipairs(databases) do
    print(string.format("    [%d] %s", i, db.name))
  end

  -- Test 6: Load schemas from first database
  if #databases > 0 then
    local db = databases[1]
    print(string.format("\nTest 6: Load schemas from database '%s'", db.name))

    db:load()
    local schemas = db:get_schemas()
    print(string.format("  ✓ Loaded %d schema(s)", #schemas))

    for i, schema in ipairs(schemas) do
      print(string.format("    [%d] %s", i, schema.name))
    end

    -- Test 7: Load tables from first schema
    if #schemas > 0 then
      local schema = schemas[1]
      print(string.format("\nTest 7: Load tables from schema '%s'", schema.name))

      schema:load_tables()
      local tables = schema.tables or {}
      print(string.format("  ✓ Loaded %d table(s)", #tables))

      for i, table in ipairs(tables) do
        if i <= 5 then  -- Show first 5 tables
          print(string.format("    [%d] %s", i, table.name))
        end
      end

      -- Test 8: Get columns from first table
      if #tables > 0 then
        local table = tables[1]
        print(string.format("\nTest 8: Get columns from table '%s'", table.name))

        local columns = table:get_columns()
        print(string.format("  ✓ Loaded %d column(s)", #columns))

        for i, col in ipairs(columns) do
          if i <= 10 then  -- Show first 10 columns
            print(string.format("    [%d] %s", i, col:get_display_name()))
          end
        end

        -- Test 9: Generate SQL
        print(string.format("\nTest 9: Generate SQL for table '%s'", table.name))
        local select_sql = table:generate_select(10)
        print("  SELECT statement:")
        print("    " .. select_sql)

        local insert_sql = table:generate_insert()
        print("  INSERT statement:")
        for line in insert_sql:gmatch("[^\r\n]+") do
          print("    " .. line)
        end
      end
    end
  end
else
  print("  ✗ Failed to load databases")
end

-- Test 10: Async query execution
print("\nTest 10: Async query execution")
print("  Executing async query...")
Connection.execute_async(test_conn, "SELECT GETDATE() AS current_time", function(results, err)
  if err then
    print(string.format("  ✗ Async query failed: %s", err))
  else
    print(string.format("  ✓ Async query completed, got %d results", #results))
    if #results > 0 then
      print("  Result:")
      for k, v in pairs(results[1]) do
        print(string.format("    %s = %s", k, v))
      end
    end
  end
end)

-- Wait a bit for async to complete
vim.wait(1000)

-- Test 11: Connection pool stats
print("\nTest 11: Connection pool statistics")
local pool_stats = Connection.get_pool_stats()
print(string.format("  Active connections: %d", pool_stats.active_connections))
for i, conn in ipairs(pool_stats.connections) do
  print(string.format("    [%d] %s", i, conn))
end

-- Test 12: Disconnect
print("\nTest 12: Disconnect from server")
server:disconnect()
print(string.format("  State after disconnect: %s", server.connection_state))

-- Verify pool is cleared
local pool_stats_after = Connection.get_pool_stats()
print(string.format("  Active connections after disconnect: %d", pool_stats_after.active_connections))

print("\n=== Connection Tests Complete ===\n")

-- Usage instructions
print("To run this test:")
print("  1. Ensure vim-dadbod is installed")
print("  2. Ensure SQL Server is running with a 'vim_dadbod_test' database")
print("  3. Run: :luafile examples/connection_test.lua")
print()
