---Database connection management for SSNS
---Wraps vim-dadbod's db#adapter#dispatch and db#systemlist
local Connection = {}

---Check if vim-dadbod is available
---@return boolean available
function Connection.is_dadbod_available()
  -- Check if we can find the autoload file
  local db_path = vim.fn.globpath(vim.o.runtimepath, "autoload/db.vim")
  return db_path ~= ""
end

---Test a database connection
---@param connection_string string The connection string to test
---@return boolean success
---@return string? error_message
function Connection.test(connection_string)
  if not Connection.is_dadbod_available() then
    return false, "vim-dadbod is not available"
  end

  -- Try to get the adapter
  local success, adapter = pcall(function()
    return vim.fn['db#adapter#dispatch'](connection_string, "interactive")
  end)

  if not success then
    return false, "Invalid connection string or unsupported database type"
  end

  -- Try a simple query to test connection
  local test_query = "SELECT 1"

  local results, err = Connection.execute_sync(connection_string, test_query)

  if err then
    return false, err
  end

  return true, nil
end

---Execute a synchronous query using vim-dadbod
---@param connection_string string The connection string or connection object
---@param query string The SQL query to execute
---@param opts table? Options { use_delimiter: boolean, include_headers: boolean }
---@return table results Array of result rows
---@return string? error_message Error message if query failed
function Connection.execute_sync(connection_string, query, opts)
  opts = opts or {}
  local use_delimiter = opts.use_delimiter == nil and true or opts.use_delimiter
  local include_headers = opts.include_headers or false

  if not Connection.is_dadbod_available() then
    return {}, "vim-dadbod not available"
  end

  -- Get the connection URL
  local conn_str = type(connection_string) == "string" and connection_string or connection_string.connection_string

  -- Get the command array using db#adapter#dispatch
  local success, cmd = pcall(function()
    return vim.fn["db#adapter#dispatch"](conn_str, "interactive")
  end)

  if not success then
    return {}, "Failed to get database adapter: " .. tostring(cmd)
  end

  -- Add sqlcmd flags for cleaner output
  -- Note: -h and -y 0 are mutually exclusive, so we only use -h for delimited queries

  if use_delimiter then
    -- For structured data (database lists, table lists):
    -- -W: Remove trailing spaces
    -- -s|: Use pipe as column separator
    -- -h-1: Remove headers (only if not include_headers)
    if not include_headers then
      table.insert(cmd, "-h-1")
    end
    table.insert(cmd, "-W")
    table.insert(cmd, "-s|")
  else
    -- For multi-line text (definitions):
    -- -y 0: Variable-length type display (unlimited width)
    -- Note: Cannot use -h-1 with -y 0 (mutually exclusive)
    -- Note: Cannot use -W with -y (mutually exclusive)
    table.insert(cmd, "-y")
    table.insert(cmd, "0")
  end

  -- Prepend SET statements for SQL Server compatibility
  -- SET NOCOUNT ON: Prevent row count messages
  -- SET QUOTED_IDENTIFIER ON: Required for indexed views, computed columns, filtered indexes
  local clean_query = "SET NOCOUNT ON; SET QUOTED_IDENTIFIER ON;\n" .. query

  -- Execute query using db#systemlist
  local results_raw
  success, results_raw = pcall(function()
    return vim.fn["db#systemlist"](cmd, clean_query)
  end)

  if not success then
    return {}, "Query execution failed: " .. tostring(results_raw)
  end

  -- Check if results indicate an error
  if type(results_raw) == "table" and #results_raw > 0 then
    local first_line = results_raw[1] or ""
    if first_line:match("^Msg %d+") or first_line:match("^Error") then
      return {}, table.concat(results_raw, "\n")
    end
  end

  -- Parse the results
  local parsed_results
  if use_delimiter then
    parsed_results = Connection.parse_result(results_raw, "|", 0, include_headers)
  else
    -- No delimiter - treat as raw multi-line text
    parsed_results = Connection.parse_result_raw(results_raw)
  end
  return parsed_results, nil
end

---Parse vim-dadbod result into table format
---@param result any Raw result from vim-dadbod (array of lines or string)
---@param delimiter string? Column delimiter (default "|")
---@param expected_columns number? Expected number of columns (0 = auto-detect)
---@param has_headers boolean? Whether first row contains column names (default false)
---@return table parsed Array of row tables
function Connection.parse_result(result, delimiter, expected_columns, has_headers)
  delimiter = delimiter or "|"
  expected_columns = expected_columns or 0

  local lines = {}

  -- Convert result to lines array
  if type(result) == "table" then
    -- Already an array of lines from db#systemlist
    lines = result
  elseif type(result) == "string" then
    -- Split string into lines
    lines = vim.split(result, "\n", { plain = true })
  else
    return {}
  end

  if #lines == 0 then
    return {}
  end

  -- Remove trailing lines (vim-dadbod-ui uses [0:-3] for sqlserver)
  -- In VimScript, [0:-3] means "up to but not including the last 2 elements"
  -- In Lua with vim.list_slice, we need to slice from 1 to #lines - 2 (inclusive)
  -- But only if there are trailing empty lines
  while #lines > 0 and (lines[#lines] == "" or lines[#lines]:match("^%s*$")) do
    table.remove(lines, #lines)
  end

  -- Filter out SQL Server messages and noise
  local clean_lines = {}
  for _, line in ipairs(lines) do
    if line and line ~= "" and not line:match("^%s*$") then
      if not line:match("^Changed database context") and
         not line:match("^Msg %d+") and
         not line:match("^%(") and  -- Skip "(X rows affected)"
         not line:match("^Changed language setting") then
        table.insert(clean_lines, line)
      end
    end
  end

  if #clean_lines == 0 then
    return {}
  end

  -- Special case: single column results (like database names)
  if expected_columns == 1 then
    local rows = {}
    for _, line in ipairs(clean_lines) do
      local trimmed = vim.trim(line)
      if trimmed ~= "" then
        table.insert(rows, { [1] = trimmed, name = trimmed })
      end
    end
    return rows
  end

  -- Parse multi-column results using delimiter
  -- Mimic vim-dadbod-ui's s:results_parser logic
  local parsed_rows = {}
  for _, line in ipairs(clean_lines) do
    local columns = {}
    for col in line:gmatch("[^" .. vim.pesc(delimiter) .. "]+") do
      local trimmed = vim.trim(col)
      if trimmed ~= "" then
        table.insert(columns, trimmed)
      end
    end

    if #columns > 0 then
      table.insert(parsed_rows, columns)
    end
  end

  if #parsed_rows == 0 then
    return {}
  end

  -- Auto-detect expected column count if not specified
  if expected_columns == 0 then
    -- Find the most common column count (like vim-dadbod-ui does with max())
    local col_counts = {}
    for _, row in ipairs(parsed_rows) do
      table.insert(col_counts, #row)
    end
    expected_columns = math.max(unpack(col_counts))
  end

  -- Filter rows to only include those with expected column count
  local filtered_rows = {}
  for _, row in ipairs(parsed_rows) do
    if #row == expected_columns then
      table.insert(filtered_rows, row)
    end
  end

  if #filtered_rows == 0 then
    return {}
  end

  -- If has_headers is true, first row contains column names
  local header = nil
  local data_rows = filtered_rows

  if has_headers and #filtered_rows > 0 then
    header = filtered_rows[1]
    data_rows = vim.list_slice(filtered_rows, 2, #filtered_rows)
  end

  -- Convert arrays to objects
  local result_objects = {}
  for _, row in ipairs(data_rows) do
    local obj = {}
    for idx, value in ipairs(row) do
      if header then
        -- Use column name from header as key
        local col_name = header[idx] or tostring(idx)
        obj[col_name] = value
      else
        -- Use numeric key
        obj[idx] = value
      end
    end
    -- Add common field names if single column
    if #row == 1 then
      obj.name = row[1]
    end
    table.insert(result_objects, obj)
  end

  return result_objects
end

---Parse raw multi-line text result (no delimiter)
---Used for OBJECT_DEFINITION and other multi-line text queries
---@param result any Raw result from vim-dadbod
---@return table parsed Array with single row containing the full text
function Connection.parse_result_raw(result)
  local lines = {}

  -- Convert result to lines array
  if type(result) == "table" then
    lines = result
  elseif type(result) == "string" then
    lines = vim.split(result, "\n", { plain = true })
  else
    return {}
  end

  if #lines == 0 then
    return {}
  end

  -- Filter out SQL Server messages and clean up lines
  local clean_lines = {}
  for _, line in ipairs(lines) do
    if line and not line:match("^Changed database context") and
       not line:match("^Msg %d+") and
       not line:match("^%(") then  -- Skip "(X rows affected)"
      -- Remove carriage returns (\r) that show as ^M
      line = line:gsub("\r", "")
      table.insert(clean_lines, line)
    end
  end

  if #clean_lines == 0 then
    return {}
  end

  -- Join all lines into a single text value
  local full_text = table.concat(clean_lines, "\n")

  -- Clean up any remaining carriage returns (shouldn't be any with CHAR(10) in queries)
  full_text = full_text:gsub("\r\n", "\n")  -- CRLF to LF
  full_text = full_text:gsub("\r", "\n")    -- CR to LF

  -- Return as single-row result with the full text
  return {{
    [1] = full_text,
    definition = full_text,
    name = full_text
  }}
end

---Execute an asynchronous query using vim-dadbod
---@param connection_string string The connection string
---@param query string The SQL query to execute
---@param callback function Callback function(results, error)
function Connection.execute_async(connection_string, query, callback)
  if not Connection.is_dadbod_available() then
    callback({}, "vim-dadbod not available")
    return
  end

  -- Use vim.schedule to run in background
  vim.schedule(function()
    local results, err = Connection.execute_sync(connection_string, query)
    callback(results, err)
  end)
end

---Execute multiple queries in sequence
---@param connection_string string The connection string
---@param queries string[] Array of queries to execute
---@return table[] results Array of result sets (one per query)
---@return string? error_message Error message if any query failed
function Connection.execute_batch(connection_string, queries)
  local all_results = {}

  for i, query in ipairs(queries) do
    local results, err = Connection.execute_sync(connection_string, query)

    if err then
      return all_results, string.format("Query %d failed: %s", i, err)
    end

    table.insert(all_results, results)
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

  local _, err = Connection.execute_sync(connection_string, query)

  if err then
    return false, err
  end

  return true, nil
end

---Get the current database name from connection
---@param connection_string string
---@return string? database_name
function Connection.get_current_database(connection_string)
  local query = "SELECT DB_NAME() AS current_database;"

  local results, err = Connection.execute_sync(connection_string, query)

  if err or #results == 0 then
    return nil
  end

  return results[1].current_database or results[1][1]
end

---Create a new connection object with state
---@param connection_string string
---@return table connection Connection object with methods
function Connection.new(connection_string)
  local conn = {
    connection_string = connection_string,
    current_database = nil,
  }

  ---Execute query on this connection
  ---@param query string
  ---@return table results
  ---@return string? error
  function conn:execute(query)
    return Connection.execute_sync(self.connection_string, query)
  end

  ---Execute async query on this connection
  ---@param query string
  ---@param callback function
  function conn:execute_async(query, callback)
    Connection.execute_async(self.connection_string, query, callback)
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
