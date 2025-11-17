---Database connection management for SSNS
---Uses Node.js backend for SQL execution
local Connection = {}

---Test a database connection
---@param connection_string string The connection string to test
---@return boolean success
---@return string? error_message
function Connection.test(connection_string)
  -- Try a simple query to test connection
  local test_query = "SELECT 1 AS test"

  local result = Connection.execute(connection_string, test_query)

  if not result.success then
    return false, result.error and result.error.message or "Unknown error"
  end

  return true, nil
end

---Simple USE statement handler - just removes USE from beginning and extracts DB
---@param connection_string string Base connection string
---@param query string The SQL query with possible USE statement
---@return string modified_conn_string Connection string with correct database
---@return string modified_query Query with USE statement removed
local function handle_use_statement(connection_string, query)
  local Debug = require('ssns.debug')
  local ConnectionString = require('ssns.connection_string')

  -- SIMPLIFIED VERSION: Only handle USE at the very beginning
  -- Pattern: USE [database]; or USE database;
  -- Only match at start of query (after optional whitespace)

  local pattern = "^%s*USE%s+%[?([^]%;]+)%]?%s*;?"
  local target_db = query:match(pattern)

  Debug.log("handle_use_statement - input conn_string: " .. connection_string)
  Debug.log("handle_use_statement - target_db from USE: " .. tostring(target_db or "nil"))

  if target_db then
    -- Found USE statement at beginning
    -- Remove it from query
    local modified_query = query:gsub(pattern, "", 1)

    -- Use proper connection string parser to build new connection with target database
    local modified_conn = ConnectionString.with_database(connection_string, target_db)

    Debug.log("handle_use_statement - modified_conn: " .. modified_conn)
    return modified_conn, modified_query
  end

  -- No USE statement, return as-is
  Debug.log("handle_use_statement - returning original connection string")
  return connection_string, query
end

---Execute a query using Node.js backend
---@param connection_string string The connection string
---@param query string The SQL query to execute
---@param opts table? Options (reserved for future use)
---@return table result Node.js result object { success, resultSets, metadata, error }
function Connection.execute(connection_string, query, opts)
  opts = opts or {}

  -- Handle USE statement - modify connection string if needed
  local final_conn_string, final_query = handle_use_statement(connection_string, query)

  -- Call Node.js RPC function SSNSExecuteQuery
  local success, raw_result = pcall(function()
    return vim.fn.SSNSExecuteQuery({final_conn_string, final_query})
  end)

  if not success then
    -- RPC call itself failed (Node.js not available, etc.)
    return {
      success = false,
      resultSets = {},
      metadata = {},
      error = {
        message = "Node.js RPC call failed: " .. tostring(raw_result),
        code = nil,
        lineNumber = nil,
        procName = nil
      }
    }
  end

  -- Validate result type
  if type(raw_result) ~= "table" then
    return {
      success = false,
      resultSets = {},
      metadata = {},
      error = {
        message = "Unexpected result type from Node.js: " .. type(raw_result),
        code = nil,
        lineNumber = nil,
        procName = nil
      }
    }
  end

  -- Check if there was a SQL error
  local error_obj = raw_result.error
  if type(error_obj) == "table" and error_obj.message then
    return {
      success = false,
      resultSets = {},
      metadata = raw_result.metadata or {},
      error = {
        message = tostring(error_obj.message),
        code = error_obj.code,
        lineNumber = error_obj.lineNumber,
        procName = error_obj.procName
      }
    }
  end

  -- Success - return the full Node.js result object
  return {
    success = true,
    resultSets = raw_result.resultSets or raw_result["resultSets"] or {},
    metadata = raw_result.metadata or {},
    error = nil
  }
end

---Execute multiple queries in sequence
---@param connection_string string The connection string
---@param queries string[] Array of queries to execute
---@return table[] results Array of result sets (one per query)
---@return string? error_message Error message if any query failed
function Connection.execute_batch(connection_string, queries)
  local all_results = {}

  for i, query in ipairs(queries) do
    local result = Connection.execute(connection_string, query)

    if not result.success then
      local error_msg = result.error and result.error.message or "Unknown error"
      return all_results, string.format("Query %d failed: %s", i, error_msg)
    end

    table.insert(all_results, result)
  end

  return all_results, nil
end

---Switch database context (USE statement for SQL Server)
---@param connection_string string The connection string
---@param database_name string Database name to switch to
---@return boolean success
---@return string? error_message
function Connection.use_database(connection_string, database_name)
  -- For SQL Server, we need to send a USE statement
  local query = string.format("USE [%s];", database_name)

  local result = Connection.execute(connection_string, query)

  if not result.success then
    local error_msg = result.error and result.error.message or "Unknown error"
    return false, error_msg
  end

  return true, nil
end

---Get the current database name from connection
---@param connection_string string
---@return string? database_name
function Connection.get_current_database(connection_string)
  local query = "SELECT DB_NAME() AS current_database;"

  local result = Connection.execute(connection_string, query)

  if not result.success or not result.resultSets or #result.resultSets == 0 then
    return nil
  end

  local rows = result.resultSets[1].rows
  if not rows or #rows == 0 then
    return nil
  end

  return rows[1].current_database
end

---Create a new connection object with state
---@param connection_string string
---@return table connection Connection object with methods
function Connection.new(connection_string)
  local conn = {
    connection_string = connection_string,
    current_database = nil,
  }

  ---Execute query on this connection using Node.js backend
  ---@param query string
  ---@param opts table? Options
  ---@return table result Node.js result object { success, resultSets, metadata, error }
  function conn:execute(query, opts)
    return Connection.execute(self.connection_string, query, opts)
  end

  ---Switch database context
  ---@param database_name string
  ---@return boolean success
  ---@return string? error
  function conn:use_database(database_name)
    local success, err = Connection.use_database(self.connection_string, database_name)
    if success then
      self.current_database = database_name
    end
    return success, err
  end

  ---Get current database
  ---@return string? database_name
  function conn:get_current_database()
    if self.current_database then
      return self.current_database
    end

    self.current_database = Connection.get_current_database(self.connection_string)
    return self.current_database
  end

  ---Test this connection
  ---@return boolean success
  ---@return string? error
  function conn:test()
    return Connection.test(self.connection_string)
  end

  return conn
end

---Connection pool for reusing connections
---@type table<string, table>
Connection.pool = {}

---Get or create a connection from the pool
---@param connection_string string
---@return table connection Connection object
function Connection.get_or_create(connection_string)
  if not Connection.pool[connection_string] then
    Connection.pool[connection_string] = Connection.new(connection_string)
  end
  return Connection.pool[connection_string]
end

---Close and remove a connection from the pool
---@param connection_string string
function Connection.close(connection_string)
  Connection.pool[connection_string] = nil
end

---Close all connections in the pool
function Connection.close_all()
  Connection.pool = {}
end

---Get statistics about connection pool
---@return table stats {active_connections: number, connections: string[]}
function Connection.get_pool_stats()
  local stats = {
    active_connections = 0,
    connections = {},
  }

  for conn_str, _ in pairs(Connection.pool) do
    stats.active_connections = stats.active_connections + 1
    table.insert(stats.connections, conn_str)
  end

  return stats
end

---Parse connection string into components
---@param connection_string string
---@return table parsed {url: string, database: string?, scheme: string?}
function Connection.parse(connection_string)
  local parsed = {
    url = connection_string,
    database = nil,
    scheme = nil,
  }

  -- Extract scheme (database type)
  local scheme = connection_string:match("^([^:]+)://")
  if scheme then
    parsed.scheme = scheme
  end

  -- Extract database name (last part after /)
  local database = connection_string:match("/([^/]+)$")
  if database then
    parsed.database = database
  end

  return parsed
end

---Format query with proper line endings
---@param query string
---@return string formatted
function Connection.format_query(query)
  -- Ensure proper line endings
  query = query:gsub("\r\n", "\n")
  query = query:gsub("\r", "\n")

  -- Trim leading/trailing whitespace
  query = vim.trim(query)

  return query
end

---Escape special characters in strings for SQL
---@param str string
---@return string escaped
function Connection.escape_string(str)
  -- Replace single quotes with double single quotes (SQL standard)
  return str:gsub("'", "''")
end

return Connection
