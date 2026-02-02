---Database connection management for SSNS
---Uses Node.js backend for SQL execution
local Connection = {}

---Query cache for metadata queries
local QueryCache = require('ssns.query_cache')
local Connections = require('ssns.connections')

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

---Handle USE statement - extracts target database and returns modified config
---@param connection_config ConnectionData Base connection config
---@param query string The SQL query with possible USE statement
---@return ConnectionData modified_config Connection config with correct database
---@return string modified_query Query with USE statement removed
local function handle_use_statement(connection_config, query)
  -- Pattern: USE [database]; or USE database;
  -- Only match at start of query (after optional whitespace)
  local pattern = "^%s*USE%s+%[?([^]%;]+)%]?%s*;?"
  local target_db = query:match(pattern)

  if target_db then
    -- Found USE statement at beginning
    -- Remove it from query
    local modified_query = query:gsub(pattern, "", 1)

    -- Create new config with target database
    local modified_config = Connections.with_database(connection_config, target_db)

    return modified_config, modified_query
  end

  -- No USE statement, return as-is
  return connection_config, query
end

---Test a database connection
---@param connection_config ConnectionData The connection configuration
---@return boolean success
---@return string? error_message
function Connection.test(connection_config)
  -- Try a simple query to test connection
  local test_query = "SELECT 1 AS test"

  local result = Connection.execute(connection_config, test_query)

  if not result.success then
    return false, result.error and result.error.message or "Unknown error"
  end

  return true, nil
end

---Execute a query using Node.js backend
---@param connection_config ConnectionData The connection configuration
---@param query string The SQL query to execute
---@param opts table? Options { use_cache: boolean?, ttl: number? }
---@return table result Node.js result object { success, resultSets, metadata, error }
function Connection.execute(connection_config, query, opts)
  opts = opts or {}
  local use_cache = opts.use_cache == nil and true or opts.use_cache -- Default to true
  local ttl = opts.ttl -- Optional custom TTL

  -- Handle USE statement - modify connection config if needed
  local final_config, final_query = handle_use_statement(connection_config, query)

  -- Generate cache key from connection config
  local cache_key = Connections.generate_connection_key(final_config)

  -- Check cache if enabled and query is cacheable
  if use_cache and should_cache_query(final_query) then
    local cached_result = QueryCache.get(cache_key, final_query, ttl)
    if cached_result then
      -- Return cached result
      return cached_result
    end
  end

  -- Serialize connection config to JSON for Node.js RPC
  local config_json = vim.fn.json_encode(final_config)

  -- Call Node.js RPC function SSNSExecuteQuery
  local success, raw_result = pcall(function()
    return vim.fn.SSNSExecuteQuery({config_json, final_query})
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
    QueryCache.set(cache_key, final_query, result)
  end

  return result
end

---Execute multiple queries in sequence
---@param connection_config ConnectionData The connection configuration
---@param queries string[] Array of queries to execute
---@return table[] results Array of result sets (one per query)
---@return string? error_message Error message if any query failed
function Connection.execute_batch(connection_config, queries)
  local all_results = {}

  for i, query in ipairs(queries) do
    local result = Connection.execute(connection_config, query)

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
---@param connection_config ConnectionData The connection configuration
---@param query string The SQL query (may contain USE statements and GO)
---@param buffer_database string|nil Current buffer database context
---@return table result Combined result from all chunks
---@return string|nil last_database Last database from execution (for buffer state update)
function Connection.execute_with_buffer_context(connection_config, query, buffer_database)
  local QueryParser = require('ssns.query_parser')

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
    -- Build connection config for this chunk's database
    -- NOTE: SQLite doesn't support USE statements - the database IS the file
    local is_sqlite = connection_config.type == "sqlite"
    local chunk_config
    if chunk.database and not is_sqlite then
      chunk_config = Connections.with_database(connection_config, chunk.database)
    else
      chunk_config = connection_config
    end

    -- Track timing for this chunk
    local chunk_start_time = vim.loop.hrtime()

    -- Execute chunk using simple execution (bypasses USE handling)
    local result = Connection.execute(chunk_config, chunk.sql)

    local chunk_end_time = vim.loop.hrtime()
    local chunk_execution_time_ms = (chunk_end_time - chunk_start_time) / 1000000  -- Convert to milliseconds

    if not result.success then
      -- Add chunk context to error and adjust line number
      if result.error then
        result.error.chunk_number = i
        result.error.total_chunks = #chunks
        result.error.batch_number = chunk.batch_number
        result.error.chunk_database = chunk.database

        -- Adjust error line number to account for removed USE statements
        -- and position within original query
        if result.error.lineNumber and chunk.start_line then
          -- Convert lineNumber to Lua number (may come as userdata from Node.js)
          local line_num = tonumber(result.error.lineNumber)
          if line_num then
            result.error.lineNumber = line_num + chunk.start_line - 1
          end
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

  -- Multiple results - combine all result sets AND aggregate rowsAffected
  local all_result_sets = {}
  local all_rows_affected = {}

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

    -- Aggregate rowsAffected from each chunk's metadata
    if result.metadata and result.metadata.rowsAffected then
      local rows = result.metadata.rowsAffected
      if type(rows) == "table" then
        for _, count in ipairs(rows) do
          table.insert(all_rows_affected, count)
        end
      elseif type(rows) == "number" then
        table.insert(all_rows_affected, rows)
      end
    end
  end

  -- Build combined metadata with aggregated rowsAffected
  local combined_metadata = metadata or {}
  if #all_rows_affected > 0 then
    combined_metadata.rowsAffected = all_rows_affected
  end

  return {
    success = true,
    resultSets = all_result_sets,
    metadata = combined_metadata
  }
end

---Switch database context (USE statement for SQL Server)
---@param connection_config ConnectionData The connection configuration
---@param database_name string Database name to switch to
---@return boolean success
---@return string? error_message
function Connection.use_database(connection_config, database_name)
  -- For SQL Server, we need to send a USE statement
  local query = string.format("USE [%s];", database_name)

  local result = Connection.execute(connection_config, query)

  if not result.success then
    local error_msg = result.error and result.error.message or "Unknown error"
    return false, error_msg
  end

  return true, nil
end

---Get the current database name from connection
---@param connection_config ConnectionData
---@return string? database_name
function Connection.get_current_database(connection_config)
  local query = "SELECT DB_NAME() AS current_database;"

  local result = Connection.execute(connection_config, query)

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
---@param connection_config ConnectionData
---@return table connection Connection object with methods
function Connection.new(connection_config)
  local conn = {
    connection_config = connection_config,
    current_database = nil,
  }

  ---Execute query on this connection using Node.js backend
  ---@param query string
  ---@param opts table? Options
  ---@return table result Node.js result object { success, resultSets, metadata, error }
  function conn:execute(query, opts)
    return Connection.execute(self.connection_config, query, opts)
  end

  ---Switch database context
  ---@param database_name string
  ---@return boolean success
  ---@return string? error
  function conn:use_database(database_name)
    local success, err = Connection.use_database(self.connection_config, database_name)
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

    self.current_database = Connection.get_current_database(self.connection_config)
    return self.current_database
  end

  ---Test this connection
  ---@return boolean success
  ---@return string? error
  function conn:test()
    return Connection.test(self.connection_config)
  end

  return conn
end

---Connection pool for reusing connections (keyed by generated connection key)
---@type table<string, table>
Connection.pool = {}

---Get or create a connection from the pool
---@param connection_config ConnectionData
---@return table connection Connection object
function Connection.get_or_create(connection_config)
  local key = Connections.generate_connection_key(connection_config)
  if not Connection.pool[key] then
    Connection.pool[key] = Connection.new(connection_config)
  end
  return Connection.pool[key]
end

---Close and remove a connection from the pool
---@param connection_config ConnectionData
function Connection.close(connection_config)
  local key = Connections.generate_connection_key(connection_config)
  Connection.pool[key] = nil
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

  for conn_key, _ in pairs(Connection.pool) do
    stats.active_connections = stats.active_connections + 1
    table.insert(stats.connections, conn_key)
  end

  return stats
end

---Invalidate cached query results for a specific connection
---@param connection_config ConnectionData
---@return number count Number of cache entries removed
function Connection.invalidate_cache(connection_config)
  local key = Connections.generate_connection_key(connection_config)
  return QueryCache.invalidate_connection(key)
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

-- ============================================================================
-- RPC ASYNC EXECUTION (Non-blocking)
-- ============================================================================
-- These methods use the async RPC mechanism where the query runs in Node.js
-- and calls back when complete. The UI remains responsive during execution.

---@class RPCAsyncExecuteOpts
---@field on_complete fun(result: table, error: string?)? Completion callback
---@field on_error fun(error: string)? Error callback
---@field timeout_ms number? Timeout in milliseconds (default: 60000)
---@field use_cache boolean? Use query cache (default: false for async)

---Execute a query with non-blocking RPC async (UI stays responsive)
---The query runs in Node.js and calls back when complete
---@param connection_config ConnectionData The connection configuration
---@param query string The SQL query to execute
---@param opts RPCAsyncExecuteOpts? Options
---@return string callback_id Callback ID for tracking/cancellation
function Connection.execute_rpc_async(connection_config, query, opts)
  opts = opts or {}
  local AsyncRPC = require('ssns.async.rpc')

  return AsyncRPC.execute_async(connection_config, query, {
    on_complete = opts.on_complete,
    on_error = opts.on_error,
    timeout_ms = opts.timeout_ms or 60000,
  })
end

---Cancel an RPC async query
---@param callback_id string The callback ID from execute_rpc_async
---@return boolean cancelled True if query was pending and cancelled
function Connection.cancel_rpc_async(callback_id)
  local AsyncRPC = require('ssns.async.rpc')
  return AsyncRPC.cancel(callback_id)
end

---@class RPCAsyncBufferContextOpts
---@field on_complete fun(result: table, last_database: string|nil, error: string?)? Completion callback
---@field timeout_ms number? Timeout per chunk in milliseconds (default: 60000)

---Execute query with buffer context using truly non-blocking RPC async
---Handles multi-database queries with USE statements and GO separators
---The event loop stays free during execution, allowing spinner animation
---@param connection_config ConnectionData Connection configuration
---@param query string SQL query (may contain USE statements and GO)
---@param buffer_database string|nil Current buffer database context
---@param opts RPCAsyncBufferContextOpts? Options
---@return string first_callback_id For tracking (first chunk's callback ID)
function Connection.execute_with_buffer_context_rpc_async(connection_config, query, buffer_database, opts)
  opts = opts or {}
  local QueryParser = require('ssns.query_parser')
  local AsyncRPC = require('ssns.async.rpc')
  local Connections = require('ssns.connections')

  -- Parse query into chunks (sync operation, fast)
  local chunks, debug_info = QueryParser.parse_query(query, buffer_database)

  -- If no chunks, return empty success result immediately
  if #chunks == 0 then
    if opts.on_complete then
      vim.schedule(function()
        opts.on_complete({
          success = true,
          resultSets = {},
          metadata = {
            total_chunks = 0,
            execution_time = 0
          }
        }, buffer_database, nil)
      end)
    end
    return "empty_query"
  end

  -- State for sequential chunk execution
  local all_results = {}
  local last_database = buffer_database
  local total_start_time = vim.loop.hrtime()
  local current_chunk_idx = 1
  local first_callback_id = nil
  local timeout_ms = opts.timeout_ms or 60000

  -- Forward declaration for recursive execution
  local execute_next_chunk

  ---Combine results from all chunks and call completion callback
  local function finalize_results()
    local total_time = (vim.loop.hrtime() - total_start_time) / 1e9
    local total_time_ms = total_time * 1000

    -- Combine results using the same logic as sync version
    local combined = combine_multi_chunk_results(all_results, {
      total_chunks = #chunks,
      go_batches = debug_info.go_batches,
      total_execution_time = total_time,
      total_execution_time_ms = total_time_ms
    })

    if opts.on_complete then
      opts.on_complete(combined, last_database, nil)
    end
  end

  ---Execute a single chunk and chain to the next
  ---@param chunk_idx number Index of chunk to execute (1-based)
  execute_next_chunk = function(chunk_idx)
    if chunk_idx > #chunks then
      -- All chunks complete
      finalize_results()
      return
    end

    local chunk = chunks[chunk_idx]

    -- Build connection config for this chunk's database
    -- NOTE: SQLite doesn't support USE statements - the database IS the file
    local is_sqlite = connection_config.type == "sqlite"
    local chunk_config
    if chunk.database and not is_sqlite then
      chunk_config = Connections.with_database(connection_config, chunk.database)
    else
      chunk_config = connection_config
    end

    -- Track timing for this chunk
    local chunk_start_time = vim.loop.hrtime()

    -- Execute chunk using truly async RPC
    local callback_id = AsyncRPC.execute_async(chunk_config, chunk.sql, {
      timeout_ms = timeout_ms,
      on_complete = function(result, err)
        local chunk_end_time = vim.loop.hrtime()
        local chunk_execution_time_ms = (chunk_end_time - chunk_start_time) / 1000000

        -- Handle RPC-level error
        if err then
          if opts.on_complete then
            opts.on_complete({
              success = false,
              resultSets = {},
              metadata = {},
              error = {
                message = err,
                chunk_number = chunk_idx,
                total_chunks = #chunks,
              }
            }, last_database, err)
          end
          return
        end

        -- Handle SQL error in result
        if not result or not result.success then
          local error_obj = result and result.error or { message = "Unknown error" }
          -- Add chunk context to error and adjust line number
          error_obj.chunk_number = chunk_idx
          error_obj.total_chunks = #chunks
          error_obj.batch_number = chunk.batch_number
          error_obj.chunk_database = chunk.database

          -- Adjust error line number to account for removed USE statements
          -- and position within original query
          if error_obj.lineNumber and chunk.start_line then
            local line_num = tonumber(error_obj.lineNumber)
            if line_num then
              error_obj.lineNumber = line_num + chunk.start_line - 1
            end
          end

          if opts.on_complete then
            opts.on_complete({
              success = false,
              resultSets = {},
              metadata = result and result.metadata or {},
              error = error_obj
            }, last_database, nil)
          end
          return
        end

        -- Add chunk execution time and line mapping to each result set
        if result.resultSets then
          for _, resultSet in ipairs(result.resultSets) do
            resultSet.chunk_execution_time_ms = chunk_execution_time_ms
            resultSet.chunk_number = chunk_idx
            resultSet.batch_number = chunk.batch_number
            resultSet.chunk_start_line = chunk.start_line
          end
        end

        table.insert(all_results, result)

        -- Track last database for buffer state update
        if chunk.database then
          last_database = chunk.database
        end

        -- Execute next chunk
        execute_next_chunk(chunk_idx + 1)
      end,
    })

    -- Track first callback ID for the caller
    if chunk_idx == 1 then
      first_callback_id = callback_id
    end
  end

  -- Start executing chunks
  execute_next_chunk(1)

  -- Return a tracking ID (first callback ID or a generated one)
  return first_callback_id or ("rpc_multi_" .. os.time() .. "_" .. math.random(10000, 99999))
end

-- ============================================================================
-- ASYNC EXECUTION METHODS (vim.schedule based - UI freezes during query)
-- ============================================================================

---@class AsyncExecuteOpts
---@field use_cache boolean? Use query cache (default: true)
---@field ttl number? Cache TTL
---@field bufnr number? Buffer to show spinner in
---@field spinner_text string? Custom spinner text
---@field show_runtime boolean? Show runtime in spinner (default: true)
---@field timeout_ms number? Timeout in milliseconds (default: 30000)
---@field on_complete fun(result: table, error: string?)? Completion callback
---@field on_progress fun(pct: number, message: string?)? Progress callback
---@field cancel_token CancellationToken? External cancellation token

---Execute a query asynchronously with optional spinner
---@param connection_config ConnectionData The connection configuration
---@param query string The SQL query to execute
---@param opts AsyncExecuteOpts? Options
---@return string task_id Task ID for tracking/cancellation
function Connection.execute_async(connection_config, query, opts)
  opts = opts or {}
  local Async = require('ssns.async')

  -- If bufnr provided, use spinner in buffer
  if opts.bufnr then
    return Async.run_in_buffer(opts.bufnr, function(ctx)
      -- Check cancellation before starting
      if ctx.is_cancelled() then
        return nil, "Operation cancelled"
      end

      ctx.report_progress(0, opts.spinner_text or "Executing query...")

      -- Execute the sync query (the RPC is atomic, can't cancel mid-flight)
      local result = Connection.execute(connection_config, query, {
        use_cache = opts.use_cache,
        ttl = opts.ttl,
      })

      ctx.report_progress(100, "Complete")
      return result
    end, {
      name = "Execute Query",
      spinner_text = opts.spinner_text or "Executing query...",
      show_runtime = opts.show_runtime ~= false,
      timeout_ms = opts.timeout_ms or 30000,
      cancel_token = opts.cancel_token,
      on_progress = opts.on_progress,
      on_complete = opts.on_complete,
    })
  else
    -- No buffer, run without spinner
    return Async.run(function(ctx)
      if ctx.is_cancelled() then
        return nil, "Operation cancelled"
      end

      return Connection.execute(connection_config, query, {
        use_cache = opts.use_cache,
        ttl = opts.ttl,
      })
    end, {
      name = "Execute Query",
      timeout_ms = opts.timeout_ms or 30000,
      cancel_token = opts.cancel_token,
      on_progress = opts.on_progress,
      on_complete = opts.on_complete,
    })
  end
end

---@class AsyncBufferContextOpts : AsyncExecuteOpts
---@field line number? Line to show spinner on (default: 0)

---Execute query with buffer context asynchronously
---Handles multi-database queries with USE statements and GO separators
---@param connection_config ConnectionData The connection configuration
---@param query string The SQL query (may contain USE statements and GO)
---@param buffer_database string|nil Current buffer database context
---@param opts AsyncBufferContextOpts? Options
---@return string task_id Task ID for tracking/cancellation
function Connection.execute_with_buffer_context_async(connection_config, query, buffer_database, opts)
  opts = opts or {}
  local Async = require('ssns.async')

  -- Always use buffer spinner for context execution (user query)
  if opts.bufnr then
    return Async.run_in_buffer(opts.bufnr, function(ctx)
      if ctx.is_cancelled() then
        return nil, "Operation cancelled"
      end

      ctx.report_progress(0, opts.spinner_text or "Executing query...")

      -- Execute the sync version
      local result, last_database = Connection.execute_with_buffer_context(
        connection_config,
        query,
        buffer_database
      )

      ctx.report_progress(100, "Complete")

      -- Return both result and last_database as a table
      return { result = result, last_database = last_database }
    end, {
      name = "Execute Query",
      spinner_text = opts.spinner_text or "Executing query...",
      show_runtime = opts.show_runtime ~= false,
      line = opts.line or 0,
      timeout_ms = opts.timeout_ms or 60000, -- 60 seconds for user queries
      cancel_token = opts.cancel_token,
      on_progress = opts.on_progress,
      on_complete = function(combined, err)
        if opts.on_complete then
          if err then
            opts.on_complete(nil, nil, err)
          elseif combined then
            opts.on_complete(combined.result, combined.last_database, nil)
          else
            opts.on_complete(nil, nil, "No result returned")
          end
        end
      end,
    })
  else
    -- No buffer provided, run without spinner
    return Async.run(function(ctx)
      if ctx.is_cancelled() then
        return nil, "Operation cancelled"
      end

      local result, last_database = Connection.execute_with_buffer_context(
        connection_config,
        query,
        buffer_database
      )

      return { result = result, last_database = last_database }
    end, {
      name = "Execute Query",
      timeout_ms = opts.timeout_ms or 60000,
      cancel_token = opts.cancel_token,
      on_progress = opts.on_progress,
      on_complete = function(combined, err)
        if opts.on_complete then
          if err then
            opts.on_complete(nil, nil, err)
          elseif combined then
            opts.on_complete(combined.result, combined.last_database, nil)
          else
            opts.on_complete(nil, nil, "No result returned")
          end
        end
      end,
    })
  end
end

---Test a database connection asynchronously
---@param connection_config ConnectionData The connection configuration
---@param opts { on_complete: fun(success: boolean, error: string?), timeout_ms: number? }? Options
---@return string task_id Task ID
function Connection.test_async(connection_config, opts)
  opts = opts or {}
  local Async = require('ssns.async')

  return Async.run(function(ctx)
    if ctx.is_cancelled() then
      return false, "Operation cancelled"
    end

    return Connection.test(connection_config)
  end, {
    name = "Test Connection",
    timeout_ms = opts.timeout_ms or 10000, -- 10 seconds for connection test
    on_complete = function(result, err)
      if opts.on_complete then
        if err then
          opts.on_complete(false, err)
        elseif type(result) == "table" then
          -- result is {success, error_message}
          opts.on_complete(result[1] or result, result[2])
        else
          opts.on_complete(result, nil)
        end
      end
    end,
  })
end

---Execute batch of queries asynchronously with progress
---@param connection_config ConnectionData The connection configuration
---@param queries string[] Array of queries to execute
---@param opts { on_complete: fun(results: table[], error: string?), on_progress: fun(pct: number, current: number, total: number)?, timeout_ms: number?, bufnr: number? }? Options
---@return string task_id Task ID
function Connection.execute_batch_async(connection_config, queries, opts)
  opts = opts or {}
  local Async = require('ssns.async')

  local run_fn = function(ctx)
    if ctx.is_cancelled() then
      return nil, "Operation cancelled"
    end

    local Progress = Async.Progress
    local tracker = Progress.create(#queries, {
      on_update = function(pct, t)
        ctx.report_progress(pct, string.format("Query %d/%d", t.current, t.total))
        if opts.on_progress then
          opts.on_progress(pct, t.current, t.total)
        end
      end,
    })

    local all_results = {}

    for i, query in ipairs(queries) do
      -- Check cancellation before each query
      if ctx.is_cancelled() then
        return all_results, "Operation cancelled after " .. (i - 1) .. " queries"
      end

      local result = Connection.execute(connection_config, query)

      if not result.success then
        local error_msg = result.error and result.error.message or "Unknown error"
        return all_results, string.format("Query %d failed: %s", i, error_msg)
      end

      table.insert(all_results, result)
      tracker:advance()
    end

    return all_results
  end

  if opts.bufnr then
    return Async.run_in_buffer(opts.bufnr, run_fn, {
      name = "Execute Batch",
      spinner_text = string.format("Executing %d queries...", #queries),
      show_runtime = true,
      timeout_ms = opts.timeout_ms or (#queries * 30000), -- 30 seconds per query
      on_complete = opts.on_complete,
    })
  else
    return Async.run(run_fn, {
      name = "Execute Batch",
      timeout_ms = opts.timeout_ms or (#queries * 30000),
      on_complete = opts.on_complete,
    })
  end
end

return Connection
