--- Test runner module
--- Executes parsed tests and collects results
local M = {}

local utils = require("nvim-ssns.testing.utils")
local Cache = require("nvim-ssns.cache")
local Connections = require("nvim-ssns.connections")

--- Setup test connection for a specific database
--- @param test_data table Test data with database field
--- @param database_type string? Database type from folder structure (sqlserver, postgres, mysql, sqlite)
--- @return table? connection_info { server, database, connection_config } or nil on error
--- @return string? error_message Error message if setup failed
local function setup_test_connection(test_data, database_type)
  -- Get testing config
  local testing = require("nvim-ssns.testing")
  local config = testing.config

  -- Determine database type: use folder structure > test_data.db_type > default
  local db_type = database_type or test_data.db_type or config.default_connection_type

  -- Get base connection config
  local base_connection = config.connections[db_type]
  if not base_connection then
    return nil, string.format("No connection config configured for database type: %s", db_type)
  end

  -- Build full connection config with database
  local connection_config = Connections.with_database(base_connection, test_data.database)

  -- Server name for cache
  local server_name = string.format("test_%s", db_type)

  -- Get or create server
  local server, err = Cache.find_or_create_server(server_name, connection_config)
  if not server then
    return nil, string.format("Failed to create server: %s", err or "unknown error")
  end

  -- Connect to server if not already connected
  if not server:is_connected() then
    local connect_success, connect_err = server:connect()
    if not connect_success then
      return nil, string.format("Failed to connect to server: %s", connect_err or "unknown error")
    end
  end

  -- Get database (load if needed)
  local database = server:get_database(test_data.database)
  if not database then
    return nil, string.format("Database not found: %s", test_data.database)
  end

  return {
    server = server,
    database = database,
    connection_config = connection_config,
  }, nil
end

--- Run a single test (not a file - a single test case)
--- @param test_data table Single test data with number, query, cursor, expected
--- @param opts table? Optional configuration { timeout_ms: number, database_type: string }
--- @return table result Test result object
function M._run_single_test_case(test_data, opts)
  opts = opts or {}
  local timeout_ms = opts.timeout_ms or 5000 -- 5 second default timeout

  local result = {
    path = opts.file_path or "unknown",
    test_number = test_data.number,
    description = test_data.description,
    database = test_data.database,
    expected_type = test_data.expected.type,
    passed = false,
    skipped = false,
    skip_reason = nil,
    error = nil,
    comparison = nil,
    duration_ms = 0,
  }

  -- Check if test is marked as skipped
  if test_data.skip then
    result.skipped = true
    result.passed = true -- Skipped tests count as passed
    result.skip_reason = test_data.skip_reason or "Test marked as skipped"
    return result
  end

  -- Extract database_type from path (e.g., tests/sqlserver/01_category/test.lua -> sqlserver)
  -- Also handle integration subfolder: tests/integration/sqlserver/...
  local database_type = opts.database_type
  if not database_type and opts.file_path then
    database_type = opts.file_path:match("/integration/([^/]+)/") or opts.file_path:match("/tests/([^/]+)/")
  end

  -- Start timer
  local start_time = vim.loop.hrtime()

  -- Setup test connection with database_type
  local connection_info, conn_err = setup_test_connection(test_data, database_type)
  if not connection_info then
    result.error = string.format("Failed to setup connection: %s", conn_err or "unknown error")
    result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
    return result
  end

  -- Create mock buffer with test data and connection info
  local bufnr
  local success, create_err = pcall(function()
    bufnr = utils.create_mock_buffer(test_data, connection_info)
  end)

  if not success then
    result.error = string.format("Failed to create mock buffer: %s", create_err)
    result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
    return result
  end

  -- Create mock context
  local ctx = utils.create_mock_context(test_data, bufnr)

  -- Get completion source
  local Source = require("nvim-ssns.completion.source")

  -- Capture completion items
  local completion_items = nil
  local completion_done = false

  -- Call get_completions with callback
  local callback_success, callback_err = pcall(function()
    Source:get_completions(ctx, function(response)
      completion_items = response.items or {}
      completion_done = true
    end)
  end)

  if not callback_success then
    result.error = string.format("get_completions failed: %s", callback_err)
    result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6

    -- Clean up buffer
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    return result
  end

  -- Wait for completion callback (with timeout)
  local wait_start = vim.loop.hrtime()
  while not completion_done do
    -- Process pending events
    vim.wait(10, function()
      return completion_done
    end, 10)

    -- Check timeout
    local elapsed = (vim.loop.hrtime() - wait_start) / 1e6
    if elapsed > timeout_ms then
      result.error = string.format("Timeout waiting for completion (>%dms)", timeout_ms)
      result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6

      -- Clean up buffer
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      return result
    end
  end

  -- Compare results
  result.comparison = utils.compare_results(completion_items or {}, test_data.expected)
  result.passed = result.comparison.passed

  -- Calculate duration
  result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6

  -- Clean up buffer
  pcall(vim.api.nvim_buf_delete, bufnr, { force = true })

  return result
end

--- Run a single test file (may contain one or many tests)
--- @param test_file_path string Absolute path to test file
--- @param opts table? Optional configuration { timeout_ms: number, database_type: string }
--- @return table result Test result object (single test) or array of results (multi-test file)
function M.run_single_test(test_file_path, opts)
  opts = opts or {}

  -- Load test data (may be single test or array)
  local test_data, load_err = utils.load_test_file(test_file_path)
  if not test_data then
    return {
      path = test_file_path,
      passed = false,
      error = string.format("Failed to load test: %s", load_err),
    }
  end

  -- Check if this is an array of tests
  if test_data[1] ~= nil and type(test_data[1]) == "table" then
    -- Multi-test file - run each test
    local results = {}
    for _, single_test in ipairs(test_data) do
      local result = M._run_single_test_case(single_test, vim.tbl_extend("force", opts, {
        file_path = test_file_path,
      }))
      table.insert(results, result)
    end
    return results
  else
    -- Single test file
    return M._run_single_test_case(test_data, vim.tbl_extend("force", opts, {
      file_path = test_file_path,
    }))
  end
end

--- Ensure connection to database is established
--- @param connection_type string? Database type (default: from config)
--- @return boolean success True if connection established
--- @return string? error_message Error message if connection failed
local function ensure_connection(connection_type)
  -- Get testing config
  local testing = require("nvim-ssns.testing")
  local config = testing.config

  -- Use default if not specified
  connection_type = connection_type or config.default_connection_type

  -- Get connection string
  local base_connection = config.connections[connection_type]
  if not base_connection then
    return false, string.format("No connection string configured for database type: %s", connection_type)
  end

  -- Server name for cache
  local server_name = string.format("test_%s", connection_type)

  -- Get or create server (without database)
  local server, err = Cache.find_or_create_server(server_name, base_connection)
  if not server then
    return false, string.format("Failed to create server: %s", err or "unknown error")
  end

  -- Connect to server if not already connected
  if not server:is_connected() then
    local connect_success, connect_err = server:connect()
    if not connect_success then
      return false, string.format("Failed to connect to server: %s", connect_err or "unknown error")
    end
    vim.notify(string.format("Connected to %s test database", connection_type), vim.log.levels.INFO)
  else
    vim.notify(string.format("Already connected to %s test database", connection_type), vim.log.levels.INFO)
  end

  return true, nil
end

--- Run all tests in the test directory
--- @param opts table? Optional configuration
--- @return table results Array of test results
function M.run_all_tests(opts)
  opts = opts or {}

  -- Get reporter for incremental output
  local reporter = require("nvim-ssns.testing.reporter")

  -- Scan for test files
  local all_test_files = utils.scan_test_folders()

  -- Filter out unit tests (they have different format and should use unit_runner)
  local test_files = {}
  for _, test_file in ipairs(all_test_files) do
    if not test_file.is_unit then
      table.insert(test_files, test_file)
    end
  end

  if #test_files == 0 then
    vim.notify("No test files found", vim.log.levels.WARN)
    return {}
  end

  -- Group tests by database type
  local tests_by_db = {}
  for _, test_file in ipairs(test_files) do
    local db_type = test_file.database_type
    if not tests_by_db[db_type] then
      tests_by_db[db_type] = {}
    end
    table.insert(tests_by_db[db_type], test_file)
  end

  vim.notify(string.format("Running %d tests across %d database types...", #test_files, vim.tbl_count(tests_by_db)), vim.log.levels.INFO)

  -- Start incremental results file
  local output_path = vim.fn.stdpath("data") .. "/ssns/test_results_live.md"
  reporter.start_incremental(output_path, #test_files)

  local results = {}
  local global_test_index = 0

  -- Run tests for each database type
  for db_type, db_test_files in pairs(tests_by_db) do
    vim.notify(string.format("Testing %s (%d tests)...", db_type, #db_test_files), vim.log.levels.INFO)

    -- Ensure connection for this database type
    local conn_success, conn_err = ensure_connection(db_type)
    if not conn_success then
      vim.notify(string.format("Failed to connect to %s: %s", db_type, conn_err), vim.log.levels.ERROR)
      -- Skip tests for this database type
      for _, test_file in ipairs(db_test_files) do
        global_test_index = global_test_index + 1
        local fail_result = {
          path = test_file.path,
          category = test_file.category,
          name = test_file.name,
          database_type = test_file.database_type,
          passed = false,
          error = string.format("Database connection failed: %s", conn_err),
          test_number = 0,
          description = test_file.name,
        }
        table.insert(results, fail_result)
        reporter.write_incremental_result(fail_result, global_test_index, #test_files)
      end
    else
      -- Run tests for this database type
      for i, test_file in ipairs(db_test_files) do
        global_test_index = global_test_index + 1

        -- Show progress
        if i % 10 == 0 or i == 1 then
          vim.notify(string.format("[%s] Running test %d/%d...", db_type, i, #db_test_files), vim.log.levels.INFO)
        end

        -- Mark test as running BEFORE execution (so we know which test hangs)
        reporter.mark_test_running({
          number = 0,
          name = test_file.name,
          category = test_file.category,
          path = test_file.path,
        }, global_test_index, #test_files)

        local result = M.run_single_test(test_file.path, vim.tbl_extend("force", opts, { database_type = test_file.database_type }))
        result.category = test_file.category
        result.name = test_file.name
        result.database_type = test_file.database_type
        table.insert(results, result)

        -- Write result immediately after completion
        reporter.write_incremental_result(result, global_test_index, #test_files)
      end
    end
  end

  -- Finish incremental file with summary
  reporter.finish_incremental(results)

  vim.notify(string.format("Completed %d tests", #results), vim.log.levels.INFO)
  vim.notify(string.format("Live results written to: %s", output_path), vim.log.levels.INFO)

  return results
end

--- Run tests in a specific category folder
--- @param category_folder string Category folder name (e.g., "01_schema_table_qualification")
--- @param opts table? Optional configuration
--- @return table results Array of test results
function M.run_category_tests(category_folder, opts)
  opts = opts or {}

  -- Scan for all test files
  local all_test_files = utils.scan_test_folders()

  -- Filter by category (excluding unit tests)
  local category_tests = {}
  for _, test_file in ipairs(all_test_files) do
    -- Skip unit tests
    if test_file.is_unit then
      goto continue
    end
    -- Match category with or without numeric prefix
    if test_file.category == category_folder or test_file.category:match("^%d+_" .. category_folder .. "$") then
      table.insert(category_tests, test_file)
    end
    ::continue::
  end

  if #category_tests == 0 then
    vim.notify(string.format("No tests found in category: %s", category_folder), vim.log.levels.WARN)
    return {}
  end

  vim.notify(string.format("Running %d tests in category: %s", #category_tests, category_folder), vim.log.levels.INFO)

  local results = {}

  -- Run each test in category
  for i, test_file in ipairs(category_tests) do
    vim.notify(string.format("Running test %d/%d: %s", i, #category_tests, test_file.name), vim.log.levels.INFO)

    local result = M.run_single_test(test_file.path, vim.tbl_extend("force", opts, { database_type = test_file.database_type }))
    result.category = test_file.category
    result.name = test_file.name
    result.database_type = test_file.database_type
    table.insert(results, result)
  end

  return results
end

--- Run tests filtered by completion type
--- @param completion_type string Completion type (e.g., "table", "column", "schema")
--- @param opts table? Optional configuration
--- @return table results Array of test results
function M.run_tests_by_type(completion_type, opts)
  opts = opts or {}

  -- Scan for all test files (excluding unit tests)
  local scanned_files = utils.scan_test_folders()
  local all_test_files = {}
  for _, test_file in ipairs(scanned_files) do
    if not test_file.is_unit then
      table.insert(all_test_files, test_file)
    end
  end

  vim.notify(string.format("Filtering tests by type: %s", completion_type), vim.log.levels.INFO)

  local filtered_results = {}

  -- Run each test and filter by type
  for i, test_file in ipairs(all_test_files) do
    -- Load test data to check expected type
    local test_data, _ = utils.load_test_file(test_file.path)

    if test_data and test_data.expected.type == completion_type then
      vim.notify(string.format("Running test %s (%s)", test_file.name, completion_type), vim.log.levels.INFO)

      local result = M.run_single_test(test_file.path, vim.tbl_extend("force", opts, { database_type = test_file.database_type }))
      result.category = test_file.category
      result.name = test_file.name
      result.database_type = test_file.database_type
      table.insert(filtered_results, result)
    end
  end

  if #filtered_results == 0 then
    vim.notify(string.format("No tests found for type: %s", completion_type), vim.log.levels.WARN)
  else
    vim.notify(string.format("Completed %d tests for type: %s", #filtered_results, completion_type), vim.log.levels.INFO)
  end

  return filtered_results
end

--- Find a specific test by number
--- @param test_number number Test number to find
--- @return string? path Path to test file or nil if not found
function M.find_test_by_number(test_number)
  local all_test_files = utils.scan_test_folders()

  for _, test_file in ipairs(all_test_files) do
    -- Skip unit tests (they use different ID format)
    if test_file.is_unit then
      goto continue
    end
    local test_data, _ = utils.load_test_file(test_file.path)
    if test_data and test_data.number == test_number then
      return test_file.path
    end
    ::continue::
  end

  return nil
end

return M
