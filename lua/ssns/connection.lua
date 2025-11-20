---Database connection management for SSNS
---Uses Node.js backend for SQL execution
local Connection = {}

---Query cache for metadata queries
local QueryCache = require('ssns.query_cache')

---Check if a query should be cached
---@param query string The SQL query
---@return boolean should_cache True if query should be cached
local function should_cache_query(query)
  local normalized = vim.trim(query):upper()

  -- Don't cache data-modifying queries
  if normalized:match("^INSERT%s") or
     normalized:match("^UPDATE%s") or
     normalized:match("^DELETE%s") or
     normalized:match("^CREATE%s") or
     normalized:match("^ALTER%s") or
     normalized:match("^DROP%s") or
     normalized:match("^TRUNCATE%s") or
     normalized:match("^EXEC%s") or
     normalized:match("^EXECUTE%s") then
    return false
  end

  -- Cache SELECT queries (including metadata queries)
  if normalized:match("^SELECT%s") then
    return true
  end

  return false
end

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
---@param opts table? Options { use_cache: boolean?, ttl: number? }
---@return table result Node.js result object { success, resultSets, metadata, error }
function Connection.execute(connection_string, query, opts)
  opts = opts or {}
  local use_cache = opts.use_cache == nil and true or opts.use_cache -- Default to true
  local ttl = opts.ttl -- Optional custom TTL

  -- Handle USE statement - modify connection string if needed
  local final_conn_string, final_query = handle_use_statement(connection_string, query)

  -- Check cache if enabled and query is cacheable
  if use_cache and should_cache_query(final_query) then
    local cached_result = QueryCache.get(final_conn_string, final_query, ttl)
    if cached_result then
      -- Return cached result
      return cached_result
    end
  end

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
  local result = {
    success = true,
    resultSets = raw_result.resultSets or raw_result["resultSets"] or {},
    metadata = raw_result.metadata or {},
    error = nil
  }

  -- Cache successful results if caching is enabled and query is cacheable
  if use_cache and should_cache_query(final_query) then
    QueryCache.set(final_conn_string, final_query, result)
  end

  return result
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

---Execute query with buffer database context
---Handles multi-database queries with USE statements and GO separators
---@param connection_string string The connection string
---@param query string The SQL query (may contain USE statements and GO)
---@param buffer_database string|nil Current buffer database context
---@return table result Combined result from all chunks
---@return string|nil last_database Last database from execution (for buffer state update)
function Connection.execute_with_buffer_context(connection_string, query, buffer_database)
  local QueryParser = require('ssns.query_parser')
  local ConnectionString = require('ssns.connection_string')

  -- Parse query with full context awareness
  local chunks, debug_info = QueryParser.parse_query(query, buffer_database)

  -- If no chunks, return empty success result
  if #chunks == 0 then
    return {
      success = true,
      resultSets = {},
      metadata = {
        total_chunks = 0,
        execution_time = 0
      }
    }, buffer_database
  end

  -- Execute each chunk
  local all_results = {}
  local last_database = buffer_database
  local total_start_time = vim.loop.hrtime()

  for i, chunk in ipairs(chunks) do
    -- Build connection string for this chunk's database
    local chunk_conn_string
    if chunk.database then
      chunk_conn_string = ConnectionString.with_database(connection_string, chunk.database)
    else
      chunk_conn_string = connection_string
    end

    -- Track timing for this chunk
    local chunk_start_time = vim.loop.hrtime()

    -- Execute chunk using simple execution (bypasses USE handling)
    local result = Connection.execute(chunk_conn_string, chunk.sql)

    local chunk_end_time = vim.loop.hrtime()
    local chunk_execution_time_ms = (chunk_end_time - chunk_start_time) / 1000000  -- Convert to milliseconds

    if not result.success then
      -- Add chunk context to error and adjust line number
      if result.error then
        result.error.chunk_number = i
        result.error.total_chunks = #chunks
        result.error.batch_number = chunk.batch_number
        result.error.chunk_database = chunk.database

        -- DEBUG: Log line number adjustment
        local original_line = result.error.lineNumber
        vim.notify(string.format("DEBUG: Error original line=%s, chunk.start_line=%s",
          tostring(original_line), tostring(chunk.start_line)), vim.log.levels.INFO)

        -- Adjust error line number to account for removed USE statements
        -- and position within original query
        if result.error.lineNumber and chunk.start_line then
          result.error.lineNumber = result.error.lineNumber + chunk.start_line - 1
          vim.notify(string.format("DEBUG: Adjusted line number from %s to %s",
            tostring(original_line), tostring(result.error.lineNumber)), vim.log.levels.INFO)
        end
      end
      return result, last_database
    end

    -- Add chunk execution time and line mapping to each result set in this chunk
    if result.resultSets then
      for _, resultSet in ipairs(result.resultSets) do
        resultSet.chunk_execution_time_ms = chunk_execution_time_ms
        resultSet.chunk_number = i
        resultSet.batch_number = chunk.batch_number
        resultSet.chunk_start_line = chunk.start_line
      end
    end

    table.insert(all_results, result)

    -- Track last database for buffer state update
    if chunk.database then
      last_database = chunk.database
    end
  end

  local total_time = (vim.loop.hrtime() - total_start_time) / 1e9
  local total_time_ms = total_time * 1000  -- Convert to milliseconds for consistency

  -- Combine results
  local combined = combine_multi_chunk_results(all_results, {
    total_chunks = #chunks,
    go_batches = debug_info.go_batches,
    comments_removed = debug_info.comments_removed.line_comments_removed +
                       debug_info.comments_removed.block_comments_removed,
    total_execution_time = total_time,
    total_execution_time_ms = total_time_ms
  })

  return combined, last_database
end

---Combine results from multiple query chunks
---@param results table[] Array of result objects
---@param metadata table? Optional metadata to include
---@return table combined Combined result object
function combine_multi_chunk_results(results, metadata)
  if #results == 0 then
    return {
      success = true,
      resultSets = {},
      metadata = metadata or {}
    }
  end

  if #results == 1 then
    -- Single result - just add metadata
    local result = results[1]
    if metadata then
      result.metadata = vim.tbl_extend("force", result.metadata or {}, metadata)
    end
    return result
  end

  -- Multiple results - combine all result sets
  local all_result_sets = {}

  for i, result in ipairs(results) do
    if result.resultSets then
      -- Add all result sets from this chunk
      for _, result_set in ipairs(result.resultSets) do
        -- Add chunk identifier to result set metadata
        local enhanced_result_set = vim.deepcopy(result_set)
        enhanced_result_set.chunk_number = i
        table.insert(all_result_sets, enhanced_result_set)
      end
    end
  end

  return {
    success = true,
    resultSets = all_result_sets,
    metadata = metadata or {}
  }
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

---Invalidate cached query results for a specific connection
---@param connection_string string
---@return number count Number of cache entries removed
function Connection.invalidate_cache(connection_string)
  return QueryCache.invalidate_connection(connection_string)
end

---Clear all cached query results
function Connection.clear_cache()
  QueryCache.clear_all()
end

---Get query cache statistics
---@return table stats Cache statistics
function Connection.get_cache_stats()
  return QueryCache.get_stats()
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
