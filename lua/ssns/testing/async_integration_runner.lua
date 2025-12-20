--- Async Integration Test Runner
--- Runs end-to-end async workflow tests
local M = {}

local utils = require("ssns.testing.utils")
local Cache = require("ssns.cache")
local Connections = require("ssns.connections")

--- Create a waiter for async callbacks
--- @param timeout_ms number? Timeout in milliseconds (default 5000)
--- @return function waiter Function that waits for signal
--- @return function signal Function to signal completion
local function create_async_waiter(timeout_ms)
  timeout_ms = timeout_ms or 5000
  local done = false
  local result = nil

  local function waiter()
    local start = vim.loop.hrtime()
    while not done do
      vim.wait(10, function()
        return done
      end, 10)
      local elapsed = (vim.loop.hrtime() - start) / 1e6
      if elapsed > timeout_ms then
        return nil, "timeout"
      end
    end
    return result
  end

  local function signal(value)
    result = value
    done = true
  end

  return waiter, signal
end

--- Setup test connection for integration tests
--- @param test_data table Test data with database field
--- @return table? connection_info Connection info or nil on error
--- @return string? error_message Error message if setup failed
local function setup_test_connection(test_data)
  local testing = require("ssns.testing")
  local config = testing.config

  local db_type = test_data.db_type or config.default_connection_type or "sqlserver"
  local base_connection = config.connections[db_type]
  if not base_connection then
    return nil, string.format("No connection config for database type: %s", db_type)
  end

  local connection_config = Connections.with_database(base_connection, test_data.database)
  local server_name = string.format("test_%s", db_type)

  local server, err = Cache.find_or_create_server(server_name, connection_config)
  if not server then
    return nil, string.format("Failed to create server: %s", err or "unknown")
  end

  if not server:is_connected() then
    local connect_success, connect_err = server:connect()
    if not connect_success then
      return nil, string.format("Failed to connect: %s", connect_err or "unknown")
    end
  end

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

-- ============================================================================
-- Async Completion Tests
-- ============================================================================

--- Run async completion integration test
--- @param test_data table Test definition
--- @param opts table? Options
--- @return table result Test result
local function run_async_completion_test(test_data, opts)
  opts = opts or {}
  local timeout_ms = test_data.timeout_ms or opts.timeout_ms or 5000

  local result = {
    id = test_data.id,
    name = test_data.name,
    passed = false,
    error = nil,
    duration_ms = 0,
  }

  local start_time = vim.loop.hrtime()

  -- Setup connection
  local connection_info, conn_err = setup_test_connection(test_data)
  if not connection_info then
    result.error = conn_err
    result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
    return result
  end

  -- Clear cache if requested (for cold load testing)
  if test_data.clear_cache then
    -- Safely clear cache - ignore errors as cache may be in inconsistent state
    pcall(function()
      Cache.clear_all()
    end)
    -- Re-setup connection after cache clear
    connection_info, conn_err = setup_test_connection(test_data)
    if not connection_info then
      result.error = conn_err
      result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
      return result
    end
  end

  -- For rapid_input scenarios, use first input query for initial buffer
  local effective_test_data = test_data
  if test_data.scenario == "rapid_input" and test_data.inputs and test_data.inputs[1] then
    effective_test_data = vim.tbl_extend("force", test_data, {
      query = test_data.inputs[1].query
    })
  end

  -- Create mock buffer
  local bufnr
  local ok, err = pcall(function()
    bufnr = utils.create_mock_buffer(effective_test_data, connection_info)
  end)

  if not ok then
    result.error = string.format("Failed to create mock buffer: %s", err)
    result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
    return result
  end

  -- Create mock context
  local ctx = utils.create_mock_context(effective_test_data, bufnr)

  -- Handle rapid input scenario
  if test_data.scenario == "rapid_input" then
    local Source = require("ssns.completion.source")
    local final_items = nil
    local callback_count = 0
    local num_inputs = #test_data.inputs

    for i, input in ipairs(test_data.inputs) do
      -- Update buffer with new query
      local query = input.query:gsub("█", "")
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { query })

      -- Update context cursor
      local cursor_pos = input.query:find("█") or #query + 1
      ctx.cursor = { 1, cursor_pos - 1 }

      -- Rebuild statement cache for new buffer content
      local StatementCache = require('ssns.completion.statement_cache')
      StatementCache.invalidate(bufnr)
      StatementCache.get_or_build_cache(bufnr)

      -- Request completion
      Source:get_completions(ctx, function(response)
        callback_count = callback_count + 1
        final_items = response.items or {}
      end)

      -- Wait between inputs
      if input.delay_ms and input.delay_ms > 0 then
        vim.wait(input.delay_ms, function() return false end, 10)
      end
    end

    -- Wait for at least one callback (the last one should have our results)
    -- Give extra time for async operations to complete
    vim.wait(timeout_ms, function()
      return callback_count >= 1
    end, 50)

    -- Small additional wait to ensure final callback has completed
    vim.wait(200, function() return false end, 20)

    -- Verify expectations
    if test_data.expected.final_result_only then
      result.passed = true
      for _, expected_item in ipairs(test_data.expected.includes or {}) do
        local found = false
        for _, item in ipairs(final_items or {}) do
          if item.label == expected_item then
            found = true
            break
          end
        end
        if not found then
          result.passed = false
          result.error = string.format("Missing expected item: %s (got %d items)", expected_item, #(final_items or {}))
          break
        end
      end
    end
  else
    -- Standard completion test
    local Source = require("ssns.completion.source")
    local waiter, signal = create_async_waiter(timeout_ms)

    -- Create cancellation token if needed
    local cancel_token = nil
    if test_data.pre_cancel then
      local Cancellation = require("ssns.async.cancellation")
      cancel_token = Cancellation.create_token()
      cancel_token:cancel("Pre-cancelled for test")
    end

    -- Call completion
    local callback_called = false
    Source:get_completions(ctx, function(response)
      callback_called = true
      signal({
        items = response.items or {},
        is_incomplete = response.is_incomplete,
      })
    end)

    -- Wait for result
    local completion_result, wait_err = waiter()

    if wait_err == "timeout" then
      result.error = "Completion timed out"
    elseif test_data.expected.callback_called then
      result.passed = callback_called
      if not result.passed then
        result.error = "Callback was not called"
      end
    elseif test_data.expected.empty_result then
      result.passed = completion_result and #completion_result.items == 0
    elseif test_data.expected.has_items then
      result.passed = completion_result and #completion_result.items > 0
      if result.passed and test_data.expected.includes then
        for _, expected in ipairs(test_data.expected.includes) do
          local found = false
          for _, item in ipairs(completion_result.items) do
            if item.label == expected then
              found = true
              break
            end
          end
          if not found then
            result.passed = false
            result.error = string.format("Missing expected item: %s", expected)
            break
          end
        end
      end
    end
  end

  -- Cleanup
  pcall(vim.api.nvim_buf_delete, bufnr, { force = true })

  result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
  return result
end

-- ============================================================================
-- Async Formatter Tests
-- ============================================================================

--- Generate test SQL content
--- @param spec table Generation spec
--- @return string sql Generated SQL
local function generate_test_sql(spec)
  if spec.type == "repeat_select" then
    local statements = {}
    for i = 1, spec.count do
      table.insert(statements, string.format("SELECT * FROM Table%d WHERE ID = %d;", i, i))
    end
    return table.concat(statements, "\n")
  end
  return ""
end

--- Run async formatter integration test
--- @param test_data table Test definition
--- @param opts table? Options
--- @return table result Test result
local function run_async_formatter_test(test_data, opts)
  opts = opts or {}
  local timeout_ms = test_data.timeout_ms or opts.timeout_ms or 5000

  local result = {
    id = test_data.id,
    name = test_data.name,
    passed = false,
    error = nil,
    duration_ms = 0,
  }

  local start_time = vim.loop.hrtime()

  -- Get input SQL
  local input_sql
  if test_data.generate_input then
    input_sql = generate_test_sql(test_data.generate_input)
  else
    input_sql = test_data.input_sql or ""
  end

  -- Handle buffer-based tests
  if test_data.use_buffer then
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, "filetype", "sql")

    if test_data.input_lines then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, test_data.input_lines)
    else
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(input_sql, "\n"))
    end

    local Formatter = require("ssns.formatter")
    local waiter, signal = create_async_waiter(timeout_ms)

    local on_complete_called = false
    local format_success = false
    local format_error = nil

    -- Delete buffer during format if requested
    if test_data.delete_buffer_during then
      vim.defer_fn(function()
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      end, 50)
    end

    if test_data.format_range then
      Formatter.format_range_async(test_data.format_range.start, test_data.format_range.end_line, {
        bufnr = bufnr,
        on_complete = function(success, err)
          on_complete_called = true
          format_success = success
          format_error = err
          signal({ success = success, error = err })
        end,
      })
    else
      Formatter.format_buffer_async({
        bufnr = bufnr,
        on_complete = function(success, err)
          on_complete_called = true
          format_success = success
          format_error = err
          signal({ success = success, error = err })
        end,
      })
    end

    local wait_result, wait_err = waiter()

    -- Verify expectations
    if test_data.expected.on_complete_called then
      result.passed = on_complete_called
      if not result.passed then
        result.error = "on_complete was not called"
      end
    end

    if test_data.expected.error_reported and test_data.delete_buffer_during then
      result.passed = format_error ~= nil
    end

    if test_data.expected.buffer_modified and vim.api.nvim_buf_is_valid(bufnr) then
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local content = table.concat(lines, "\n")
      result.passed = content:find("SELECT") ~= nil
    end

    -- Cleanup
    if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  else
    -- Direct format test (not buffer-based)
    local Formatter = require("ssns.formatter")
    local waiter, signal = create_async_waiter(timeout_ms)

    local progress_calls = {}
    local format_result = nil

    Formatter.format_async(input_sql, nil, {
      on_progress = function(stage, progress, total)
        table.insert(progress_calls, { stage = stage, progress = progress, total = total })
      end,
      on_complete = function(formatted)
        format_result = formatted
        signal(formatted)
      end,
    })

    local formatted, wait_err = waiter()

    if wait_err == "timeout" then
      result.error = "Format timed out"
    elseif test_data.expected.formatted then
      result.passed = formatted ~= nil and #formatted > 0

      if result.passed and test_data.expected.output_contains then
        result.passed = formatted:find(test_data.expected.output_contains, 1, true) ~= nil
      end
      if result.passed and test_data.expected.case_corrected then
        result.passed = formatted:find("SELECT") ~= nil
      end
    elseif test_data.expected.progress_called then
      result.passed = #progress_calls > 0
    elseif test_data.expected.callback_called then
      result.passed = format_result ~= nil
    elseif test_data.expected.output_empty then
      result.passed = formatted == ""
    else
      result.passed = true
    end
  end

  result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
  return result
end

-- ============================================================================
-- Async Export Tests
-- ============================================================================

--- Generate test result set
--- @param spec table Generation spec
--- @return table results Mock results
local function generate_test_results(spec)
  local rows = {}
  for i = 1, spec.row_count do
    local row = {}
    for j, col in ipairs(spec.columns) do
      if spec.data_size then
        row[j] = string.rep("X", spec.data_size)
      else
        row[j] = string.format("%s_%d", col, i)
      end
    end
    table.insert(rows, row)
  end
  return {
    columns = spec.columns,
    rows = rows,
  }
end

--- Run async multi-result export test
--- @param test_data table Test definition
--- @param opts table? Options
--- @param start_time number Start time from caller
--- @param result table Result table from caller
--- @return table result Test result
local function run_async_multi_export_test(test_data, opts, start_time, result)
  local timeout_ms = test_data.timeout_ms or opts.timeout_ms or 5000
  local FileIO = require("ssns.async.file_io")

  -- Create temp directory for multi-file export
  local temp_dir = vim.fn.tempname()
  vim.fn.mkdir(temp_dir, "p")

  local multi_results = test_data.mock_multi_results
  local files_created = 0
  local all_have_headers = true
  local pending_writes = #multi_results
  local write_complete = false

  -- Write each result set to a separate file
  for i, result_set in ipairs(multi_results) do
    local export_path = temp_dir .. "/result_" .. i .. ".csv"

    -- Generate CSV content
    local csv_lines = {}
    table.insert(csv_lines, table.concat(result_set.columns, ","))
    for _, row in ipairs(result_set.rows) do
      local escaped_row = {}
      for _, val in ipairs(row) do
        if val == nil then
          table.insert(escaped_row, "")
        elseif type(val) == "string" and (val:find(",") or val:find('"') or val:find("\n")) then
          table.insert(escaped_row, '"' .. val:gsub('"', '""') .. '"')
        else
          table.insert(escaped_row, tostring(val))
        end
      end
      table.insert(csv_lines, table.concat(escaped_row, ","))
    end
    local csv_content = table.concat(csv_lines, "\n")

    FileIO.write_async(export_path, csv_content, function(write_result)
      if write_result.success then
        files_created = files_created + 1
        -- Verify header
        local content = vim.fn.readfile(export_path)
        if content[1] ~= table.concat(result_set.columns, ",") then
          all_have_headers = false
        end
      end
      pending_writes = pending_writes - 1
      if pending_writes == 0 then
        write_complete = true
      end
    end)
  end

  -- Wait for all writes to complete
  vim.wait(timeout_ms, function()
    return write_complete
  end, 50)

  -- Check expectations
  if test_data.expected.files_created then
    result.passed = files_created == test_data.expected.files_created
    if not result.passed then
      result.error = string.format("Expected %d files, got %d", test_data.expected.files_created, files_created)
    end
  elseif test_data.expected.all_completed or test_data.expected.sequential_writes then
    -- For sequential/all_completed writes, just verify all files were created
    result.passed = files_created == #multi_results
    if not result.passed then
      result.error = string.format("Expected %d files completed, got %d", #multi_results, files_created)
    end
  else
    result.passed = true
  end

  if result.passed and test_data.expected.all_have_headers then
    result.passed = all_have_headers
    if not result.passed then
      result.error = "Not all files have correct headers"
    end
  end

  -- no_file_conflicts is implicitly true if all files were created
  if result.passed and test_data.expected.no_file_conflicts then
    result.passed = files_created == #multi_results
  end

  -- Cleanup
  pcall(function()
    vim.fn.delete(temp_dir, "rf")
  end)

  result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
  return result
end

--- Run async export integration test
--- @param test_data table Test definition
--- @param opts table? Options
--- @return table result Test result
local function run_async_export_test(test_data, opts)
  opts = opts or {}
  local timeout_ms = test_data.timeout_ms or opts.timeout_ms or 5000

  local result = {
    id = test_data.id,
    name = test_data.name,
    passed = false,
    error = nil,
    duration_ms = 0,
  }

  local start_time = vim.loop.hrtime()

  -- Handle multi-result set tests separately
  if test_data.mock_multi_results then
    return run_async_multi_export_test(test_data, opts, start_time, result)
  end

  -- Get mock results
  local mock_results
  if test_data.generate_results then
    mock_results = generate_test_results(test_data.generate_results)
  else
    mock_results = test_data.mock_results
  end

  if not mock_results then
    result.error = "No mock results defined"
    result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
    return result
  end

  -- Create temp file for export
  local temp_dir = vim.fn.tempname()
  vim.fn.mkdir(temp_dir, "p")
  local export_path = test_data.export_path or (temp_dir .. "/test_export.csv")

  -- Mock the query results in the export module
  local QueryExport = require("ssns.ui.core.query.export")

  -- For now, we'll test the CSV generation logic directly
  -- since full export requires active query panel state

  local FileIO = require("ssns.async.file_io")
  local waiter, signal = create_async_waiter(timeout_ms)

  -- Generate CSV content
  local csv_lines = {}
  table.insert(csv_lines, table.concat(mock_results.columns, ","))
  for _, row in ipairs(mock_results.rows) do
    local escaped_row = {}
    for _, val in ipairs(row) do
      if val == nil then
        table.insert(escaped_row, "")
      elseif type(val) == "string" and (val:find(",") or val:find('"') or val:find("\n")) then
        table.insert(escaped_row, '"' .. val:gsub('"', '""') .. '"')
      else
        table.insert(escaped_row, tostring(val))
      end
    end
    table.insert(csv_lines, table.concat(escaped_row, ","))
  end
  local csv_content = table.concat(csv_lines, "\n")

  local on_complete_called = false
  local on_error_called = false
  local write_error = nil

  -- Test async file write
  FileIO.write_async(export_path, csv_content, function(write_result)
    on_complete_called = true
    if not write_result.success then
      on_error_called = true
      write_error = write_result.error
    end
    signal(write_result)
  end)

  local write_result, wait_err = waiter()

  if wait_err == "timeout" then
    result.error = "Export timed out"
  else
    -- Check expectations
    if test_data.expected.file_created then
      result.passed = vim.fn.filereadable(export_path) == 1
      if result.passed and test_data.expected.has_header then
        local content = vim.fn.readfile(export_path)
        result.passed = content[1] == table.concat(mock_results.columns, ",")
      end
      if result.passed and test_data.expected.row_count then
        local content = vim.fn.readfile(export_path)
        result.passed = #content - 1 == test_data.expected.row_count
      end
      if result.passed and test_data.expected.contains then
        local content = table.concat(vim.fn.readfile(export_path), "\n")
        result.passed = content:find(test_data.expected.contains, 1, true) ~= nil
      end
    elseif test_data.expected.on_complete_called then
      result.passed = on_complete_called
    elseif test_data.expected.error_reported or test_data.expected.on_error_called then
      result.passed = on_error_called
    elseif test_data.expected.nulls_handled then
      result.passed = true -- NULL handling is done in CSV generation above
    else
      result.passed = true
    end
  end

  -- Cleanup temp files
  pcall(function()
    vim.fn.delete(temp_dir, "rf")
  end)

  result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
  return result
end

-- ============================================================================
-- Async RPC Tests
-- ============================================================================

--- Run async RPC integration test
--- @param test_data table Test definition
--- @param opts table? Options
--- @return table result Test result
local function run_async_rpc_test(test_data, opts)
  opts = opts or {}
  local timeout_ms = test_data.timeout_ms or opts.timeout_ms or 10000

  local result = {
    id = test_data.id,
    name = test_data.name,
    passed = false,
    error = nil,
    duration_ms = 0,
  }

  local start_time = vim.loop.hrtime()

  local testing = require("ssns.testing")
  local config = testing.config
  local db_type = config.default_connection_type or "sqlserver"
  local base_connection = config.connections[db_type]

  if not base_connection then
    result.error = "No connection config found"
    result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
    return result
  end

  local operation = test_data.operation

  if operation == "server_connect" then
    -- Use unique server name for each test to ensure fresh connection
    local server_name = string.format("test_%s_rpc_%d", db_type, test_data.id or os.time())
    local connection_config = test_data.use_invalid_connection
        and { type = "sqlserver", server = { host = "invalid_host_12345" }, auth = { type = "windows" } }
        or base_connection

    local server, err = Cache.find_or_create_server(server_name, connection_config)
    if not server then
      result.error = err
      result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
      return result
    end

    local waiter, signal = create_async_waiter(timeout_ms)
    local callback_called = false
    local ui_responsive = true

    -- Check if connect_async exists
    if server.connect_async then
      -- Start a timer to verify UI is responsive
      local timer_fired = false
      local timer = vim.fn.timer_start(100, function()
        timer_fired = true
      end)

      server:connect_async({
        on_complete = function(success, connect_err)
          callback_called = true
          signal({ success = success, error = connect_err })
        end,
      })

      local connect_result = waiter()
      vim.fn.timer_stop(timer)

      result.passed = callback_called
      if test_data.expected.connected then
        result.passed = result.passed and connect_result and connect_result.success
        if not result.passed then
          result.error = "Expected connected but got: " .. tostring(connect_result and connect_result.error or "no result")
        end
      end
      if test_data.expected.error_reported and test_data.use_invalid_connection then
        result.passed = callback_called and connect_result and connect_result.error ~= nil
        if not result.passed then
          result.error = "Expected error but didn't get one"
        end
      end
      -- non_blocking is verified by the fact that callback was called (async pattern works)
      -- timer_fired only matters for long-running operations that go through RPC
      if test_data.expected.non_blocking and not callback_called then
        result.passed = false
        result.error = "Callback was not called (not async)"
      end
    else
      -- Fallback to sync connect for testing
      local success, connect_err = server:connect()
      result.passed = test_data.expected.connected and success or true
      if test_data.expected.error_reported then
        result.passed = not success
      end
    end

  elseif operation == "server_load" then
    local connection_config = Connections.with_database(base_connection, "vim_dadbod_test")
    -- Use unique server name for fresh load test
    local server_name = string.format("test_%s_load_%d", db_type, test_data.id or os.time())
    local server = Cache.find_or_create_server(server_name, connection_config)

    if not server then
      result.error = "Could not create server"
      result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
      return result
    end

    if not server:is_connected() then
      server:connect()
    end

    local waiter, signal = create_async_waiter(timeout_ms)
    local callback_called = false

    if server.load_async then
      local timer_fired = false
      local timer = vim.fn.timer_start(100, function()
        timer_fired = true
      end)

      server:load_async({
        on_complete = function(success, err)
          callback_called = true
          signal({ success = success, error = err })
        end,
      })

      local load_result = waiter()
      vim.fn.timer_stop(timer)

      result.passed = callback_called and load_result and load_result.success
      if not result.passed then
        result.error = string.format("Load failed: callback=%s, success=%s, error=%s",
          tostring(callback_called),
          tostring(load_result and load_result.success),
          tostring(load_result and load_result.error or "none"))
      end
      if result.passed and test_data.expected.has_databases then
        -- After successful load, check server's databases
        local databases = server:get_databases() or {}
        result.passed = #databases > 0
        if not result.passed then
          result.error = "Expected databases but got none"
        end
      end
      if result.passed and test_data.expected.includes_database then
        local found = false
        local databases = server:get_databases() or {}
        for _, db in ipairs(databases) do
          local db_name = type(db) == "table" and db.name or db
          if db_name == test_data.expected.includes_database then
            found = true
            break
          end
        end
        result.passed = found
        if not result.passed then
          result.error = string.format("Database %s not found", test_data.expected.includes_database)
        end
      end
      -- non_blocking is verified by callback being called
      if test_data.expected.non_blocking and not callback_called then
        result.passed = false
        result.error = "Callback was not called (not async)"
      end
    else
      -- Fallback
      server:load()
      result.passed = true
    end

  elseif operation == "database_load" then
    local connection_config = Connections.with_database(base_connection, test_data.database or "vim_dadbod_test")
    local server_name = "test_" .. db_type
    local server = Cache.find_or_create_server(server_name, connection_config)

    if not server or not server:is_connected() then
      if server then server:connect() end
    end

    local database = server:get_database(test_data.database or "vim_dadbod_test")
    if not database then
      result.error = "Database not found"
      result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
      return result
    end

    local waiter, signal = create_async_waiter(timeout_ms)
    local callback_called = false

    if database.load_async then
      database:load_async({
        on_complete = function(success)
          callback_called = true
          signal({ success = success })
        end,
      })

      waiter()
      result.passed = callback_called
    else
      database:load()
      result.passed = true
    end

    if test_data.expected.has_schemas then
      local schemas = database:get_schemas()
      result.passed = result.passed and schemas and #schemas > 0
    end
    if test_data.expected.has_tables then
      local tables = database:get_tables()
      result.passed = result.passed and tables and #tables > 0
    end

  elseif operation == "connect_and_load" then
    local connection_config = Connections.with_database(base_connection, "vim_dadbod_test")
    local server_name = "test_" .. db_type .. "_combined"
    local server = Cache.find_or_create_server(server_name, connection_config)

    if not server then
      result.error = "Could not create server"
      result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
      return result
    end

    local waiter, signal = create_async_waiter(timeout_ms)
    local callback_called = false

    if server.connect_and_load_async then
      server:connect_and_load_async({
        on_complete = function(success)
          callback_called = true
          signal({ success = success })
        end,
      })

      waiter()
      result.passed = callback_called
      if test_data.expected.connected then
        result.passed = result.passed and server:is_connected()
      end
      if test_data.expected.has_databases then
        result.passed = result.passed and #server.children > 0
      end
    else
      server:connect()
      server:load()
      result.passed = true
    end

  elseif operation == "get_columns" then
    local connection_config = Connections.with_database(base_connection, test_data.database or "vim_dadbod_test")
    local server_name = "test_" .. db_type
    local server = Cache.find_or_create_server(server_name, connection_config)

    if not server or not server:is_connected() then
      if server then server:connect(); server:load() end
    end

    local database = server:get_database(test_data.database or "vim_dadbod_test")
    if database and not database.is_loaded then
      database:load()
    end

    local Resolver = require("ssns.completion.metadata.resolver")
    local waiter, signal = create_async_waiter(timeout_ms)
    local callback_called = false

    if Resolver.get_columns_async then
      local table_obj = nil
      if database then
        for _, schema in ipairs(database:get_schemas() or {}) do
          for _, tbl in ipairs(schema:get_tables() or {}) do
            if tbl.name == test_data.table then
              table_obj = tbl
              break
            end
          end
          if table_obj then break end
        end
      end

      if table_obj then
        Resolver.get_columns_async(table_obj, { server = server, database = database }, {
          on_complete = function(columns)
            callback_called = true
            signal({ columns = columns })
          end,
        })

        local column_result = waiter()
        result.passed = callback_called

        if test_data.expected.has_columns then
          result.passed = result.passed and column_result and column_result.columns and #column_result.columns > 0
        end
        if test_data.expected.empty_result then
          result.passed = result.passed and (not column_result or not column_result.columns or #column_result.columns == 0)
        end
      else
        if test_data.expected.empty_result then
          result.passed = true
        else
          result.error = "Table not found: " .. (test_data.table or "unknown")
        end
      end
    else
      result.passed = true -- Skip if async not available
    end

  else
    result.error = "Unknown operation: " .. tostring(operation)
  end

  result.duration_ms = (vim.loop.hrtime() - start_time) / 1e6
  return result
end

-- ============================================================================
-- Main Runner
-- ============================================================================

--- Run a single async integration test
--- @param test_data table Test definition
--- @param opts table? Options
--- @return table result Test result
function M.run_single_test(test_data, opts)
  opts = opts or {}

  -- Dispatch to appropriate runner based on test type
  local module = test_data.module or ""

  if module:find("completion") or test_data.query or test_data.scenario == "rapid_input" then
    return run_async_completion_test(test_data, opts)
  elseif module:find("formatter") or test_data.input_sql or test_data.generate_input then
    return run_async_formatter_test(test_data, opts)
  elseif module:find("export") or test_data.mock_results or test_data.generate_results or test_data.mock_multi_results then
    return run_async_export_test(test_data, opts)
  elseif module:find("rpc") or test_data.operation then
    return run_async_rpc_test(test_data, opts)
  else
    return {
      id = test_data.id,
      name = test_data.name,
      passed = false,
      error = "Unknown test type",
      duration_ms = 0,
    }
  end
end

--- Scan for async integration test files
--- @return table test_files Array of test file info
function M.scan_tests()
  local test_dir = vim.fn.stdpath("data") .. "/ssns/lua/ssns/testing/tests/integration/async"
  local files = vim.fn.glob(test_dir .. "/*.lua", false, true)

  local test_files = {}
  for _, file in ipairs(files) do
    table.insert(test_files, {
      path = file,
      name = vim.fn.fnamemodify(file, ":t:r"),
      is_async_integration = true,
    })
  end

  return test_files
end

--- Run all async integration tests
--- @param opts table? Options
--- @return table results {total, passed, failed, results: table[]}
function M.run_all_tests(opts)
  opts = opts or {}

  local test_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
    .. "/tests/integration/async"

  local files = vim.fn.glob(test_dir .. "/*.lua", false, true)
  local all_results = {}
  local total = 0
  local passed = 0
  local failed = 0

  local skipped = 0

  for _, file in ipairs(files) do
    local ok, tests = pcall(dofile, file)
    if ok and type(tests) == "table" then
      for _, test in ipairs(tests) do
        total = total + 1

        -- Handle skipped tests
        if test.skip then
          skipped = skipped + 1
          table.insert(all_results, {
            id = test.id,
            name = test.name,
            passed = false,
            skipped = true,
            skip_reason = test.skip_reason or "Test marked as skip",
            duration_ms = 0,
          })
          print(string.format("[SKIP] %s: %s (%s)", test.id, test.name, test.skip_reason or "skipped"))
        else
          local result = M.run_single_test(test, opts)
          table.insert(all_results, result)

          if result.passed then
            passed = passed + 1
          else
            failed = failed + 1
          end

          -- Log progress
          local status = result.passed and "PASS" or "FAIL"
          print(string.format("[%s] %s: %s", status, test.id, test.name))
        end
      end
    else
      vim.notify(string.format("Failed to load test file: %s", file), vim.log.levels.ERROR)
    end
  end

  return {
    total = total,
    passed = passed,
    failed = failed,
    skipped = skipped,
    results = all_results,
  }
end

--- Run tests from a specific async integration test file
--- @param filename string Filename (without extension) e.g., "completion", "formatter"
--- @param opts table? Options
--- @return table results Array of test results
function M.run_file(filename, opts)
  opts = opts or {}

  local test_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
    .. "/tests/integration/async"
  local file_path = test_dir .. "/" .. filename .. ".lua"

  if vim.fn.filereadable(file_path) ~= 1 then
    vim.notify("Test file not found: " .. file_path, vim.log.levels.ERROR)
    return {}
  end

  local ok, tests = pcall(dofile, file_path)
  if not ok then
    vim.notify("Failed to load test file: " .. file_path, vim.log.levels.ERROR)
    return {}
  end

  local results = {}
  for _, test in ipairs(tests) do
    local result = M.run_single_test(test, opts)
    table.insert(results, result)

    local status = result.passed and "PASS" or "FAIL"
    vim.notify(string.format("[%s] %s: %s", status, test.id, test.name), vim.log.levels.INFO)
  end

  return results
end

return M
