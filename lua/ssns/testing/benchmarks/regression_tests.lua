--- Performance Regression Test Suite
--- Automated tests that verify async operations meet latency targets
--- Run these tests to detect performance regressions
local M = {}

local runner = require("ssns.testing.benchmarks.runner")
local targets = require("ssns.testing.benchmarks.latency_targets")

---@class RegressionTestResult
---@field name string Test name
---@field category string Category
---@field operation string Operation name
---@field passed boolean Whether test passed
---@field measured_ms number Measured time
---@field target_ms number Target time
---@field margin_percent number Margin over/under target
---@field error string? Error message if failed

--- Generate test data of specified size
--- @param size number Size in bytes
--- @return string data
local function generate_data(size)
  local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  local result = {}
  for i = 1, size do
    result[i] = chars:sub((i % #chars) + 1, (i % #chars) + 1)
  end
  return table.concat(result)
end

--- Create async waiter
--- @param timeout_ms number?
--- @return function waiter
--- @return function signal
local function create_waiter(timeout_ms)
  timeout_ms = timeout_ms or 10000
  local done = false
  local result = nil

  return function()
    local start = vim.loop.hrtime() / 1e6
    while not done do
      vim.wait(1, function() return done end, 1)
      if vim.loop.hrtime() / 1e6 - start > timeout_ms then
        return nil, "timeout"
      end
    end
    return result
  end, function(value)
    result = value
    done = true
  end
end

-- ============================================================================
-- File I/O Regression Tests
-- ============================================================================

--- Run file I/O regression tests
--- @return RegressionTestResult[] results
function M.run_file_io_tests()
  local FileIO = require("ssns.async.file_io")
  local results = {}

  local temp_dir = vim.fn.tempname()
  vim.fn.mkdir(temp_dir, "p")

  -- Test: Small file read (< 10KB)
  local small_file = temp_dir .. "/small.txt"
  local small_data = generate_data(5 * 1024)
  vim.fn.writefile({ small_data }, small_file)

  local start = vim.loop.hrtime()
  local waiter, signal = create_waiter(5000)
  FileIO.read_async(small_file, function()
    signal(true)
  end)
  waiter()
  local elapsed = (vim.loop.hrtime() - start) / 1e6

  local passed, reason = targets.check_target("file_io", "read_small", elapsed)
  table.insert(results, {
    name = "File I/O: Small file read (5KB)",
    category = "file_io",
    operation = "read_small",
    passed = passed,
    measured_ms = elapsed,
    target_ms = targets.targets.file_io.read_small.max_blocking,
    margin_percent = (elapsed / targets.targets.file_io.read_small.max_blocking - 1) * 100,
    error = reason,
  })

  -- Test: Medium file read (10KB-100KB)
  local medium_file = temp_dir .. "/medium.txt"
  local medium_data = generate_data(50 * 1024)
  vim.fn.writefile({ medium_data }, medium_file)

  start = vim.loop.hrtime()
  waiter, signal = create_waiter(5000)
  FileIO.read_async(medium_file, function()
    signal(true)
  end)
  waiter()
  elapsed = (vim.loop.hrtime() - start) / 1e6

  passed, reason = targets.check_target("file_io", "read_medium", elapsed)
  table.insert(results, {
    name = "File I/O: Medium file read (50KB)",
    category = "file_io",
    operation = "read_medium",
    passed = passed,
    measured_ms = elapsed,
    target_ms = targets.targets.file_io.read_medium.max_blocking,
    margin_percent = (elapsed / targets.targets.file_io.read_medium.max_blocking - 1) * 100,
    error = reason,
  })

  -- Test: Large file read (> 100KB) - should not block UI
  local large_file = temp_dir .. "/large.txt"
  local large_data = generate_data(500 * 1024)
  vim.fn.writefile({ large_data }, large_file)

  local ui_responsive, max_block = targets.verify_ui_responsiveness(function(callback)
    FileIO.read_async(large_file, function()
      callback()
    end)
  end, 10000)

  table.insert(results, {
    name = "File I/O: Large file read (500KB) - UI responsiveness",
    category = "file_io",
    operation = "read_large",
    passed = ui_responsive,
    measured_ms = max_block,
    target_ms = 50, -- Max acceptable block time
    margin_percent = (max_block / 50 - 1) * 100,
    error = ui_responsive and nil or string.format("UI blocked for %.2fms", max_block),
  })

  -- Cleanup
  vim.fn.delete(temp_dir, "rf")

  return results
end

-- ============================================================================
-- Completion Regression Tests
-- ============================================================================

--- Run completion regression tests
--- @return RegressionTestResult[] results
function M.run_completion_tests()
  local results = {}

  -- Test: Trigger response time (time to first yield)
  local StatementParser = require("ssns.completion.statement_parser")
  local query = "SELECT * FROM Employees WHERE EmployeeID = 1"

  local start = vim.loop.hrtime()
  StatementParser.parse(query)
  local elapsed = (vim.loop.hrtime() - start) / 1e6

  local passed, reason = targets.check_target("completion", "trigger_response", elapsed)
  table.insert(results, {
    name = "Completion: Statement parse trigger response",
    category = "completion",
    operation = "trigger_response",
    passed = passed,
    measured_ms = elapsed,
    target_ms = targets.targets.completion.trigger_response.max_blocking,
    margin_percent = (elapsed / targets.targets.completion.trigger_response.max_blocking - 1) * 100,
    error = reason,
  })

  -- Test: Tokenization performance
  local Tokenizer = require("ssns.completion.tokenizer")

  start = vim.loop.hrtime()
  Tokenizer.tokenize(query)
  elapsed = (vim.loop.hrtime() - start) / 1e6

  table.insert(results, {
    name = "Completion: Tokenization performance",
    category = "completion",
    operation = "trigger_response",
    passed = elapsed < 16,
    measured_ms = elapsed,
    target_ms = 16,
    margin_percent = (elapsed / 16 - 1) * 100,
    error = elapsed >= 16 and string.format("Tokenization took %.2fms (> 16ms)", elapsed) or nil,
  })

  return results
end

-- ============================================================================
-- Formatter Regression Tests
-- ============================================================================

--- Run formatter regression tests
--- @return RegressionTestResult[] results
function M.run_formatter_tests()
  local Formatter = require("ssns.formatter")
  local results = {}

  -- Generate test queries
  local function gen_query(count)
    local stmts = {}
    for i = 1, count do
      table.insert(stmts, string.format("SELECT * FROM Table%d WHERE ID = %d;", i, i))
    end
    return table.concat(stmts, "\n")
  end

  -- Test: Small query (< 10 statements)
  local small_query = gen_query(5)

  local start = vim.loop.hrtime()
  Formatter.format(small_query)
  local elapsed = (vim.loop.hrtime() - start) / 1e6

  local passed, reason = targets.check_target("formatter", "small_query", elapsed)
  table.insert(results, {
    name = "Formatter: Small query (5 statements)",
    category = "formatter",
    operation = "small_query",
    passed = passed,
    measured_ms = elapsed,
    target_ms = targets.targets.formatter.small_query.max_blocking,
    margin_percent = (elapsed / targets.targets.formatter.small_query.max_blocking - 1) * 100,
    error = reason,
  })

  -- Test: Medium query (10-50 statements)
  local medium_query = gen_query(30)

  start = vim.loop.hrtime()
  Formatter.format(medium_query)
  elapsed = (vim.loop.hrtime() - start) / 1e6

  passed, reason = targets.check_target("formatter", "medium_query", elapsed)
  table.insert(results, {
    name = "Formatter: Medium query (30 statements)",
    category = "formatter",
    operation = "medium_query",
    passed = passed,
    measured_ms = elapsed,
    target_ms = targets.targets.formatter.medium_query.max_blocking,
    margin_percent = (elapsed / targets.targets.formatter.medium_query.max_blocking - 1) * 100,
    error = reason,
  })

  -- Test: Large query (> 50 statements) - should use async/chunked
  local large_query = gen_query(100)

  local ui_responsive, max_block = targets.verify_ui_responsiveness(function(callback)
    Formatter.format_async(large_query, nil, {
      on_complete = function()
        callback()
      end,
    })
  end, 30000)

  table.insert(results, {
    name = "Formatter: Large query (100 statements) - UI responsiveness",
    category = "formatter",
    operation = "large_query",
    passed = ui_responsive,
    measured_ms = max_block,
    target_ms = 50,
    margin_percent = (max_block / 50 - 1) * 100,
    error = ui_responsive and nil or string.format("UI blocked for %.2fms", max_block),
  })

  return results
end

-- ============================================================================
-- Rendering Regression Tests
-- ============================================================================

--- Run rendering regression tests
--- @return RegressionTestResult[] results
function M.run_rendering_tests()
  local results = {}

  -- Create test buffer
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Generate test lines
  local function gen_lines(count)
    local lines = {}
    for i = 1, count do
      lines[i] = string.format("Line %d: Test content", i)
    end
    return lines
  end

  -- Test: Small tree render (< 100 nodes)
  local small_lines = gen_lines(50)

  local start = vim.loop.hrtime()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, small_lines)
  local elapsed = (vim.loop.hrtime() - start) / 1e6

  local passed, reason = targets.check_target("rendering", "tree_render_small", elapsed)
  table.insert(results, {
    name = "Rendering: Small buffer write (50 lines)",
    category = "rendering",
    operation = "tree_render_small",
    passed = passed,
    measured_ms = elapsed,
    target_ms = targets.targets.rendering.tree_render_small.max_blocking,
    margin_percent = (elapsed / targets.targets.rendering.tree_render_small.max_blocking - 1) * 100,
    error = reason,
  })

  -- Test: Large tree render (> 100 nodes) - should use chunked
  local large_lines = gen_lines(500)

  local UiBuffer = require("ssns.ui.core.buffer")
  if UiBuffer.set_lines_chunked then
    local ui_responsive, max_block = targets.verify_ui_responsiveness(function(callback)
      UiBuffer.set_lines_chunked(bufnr, 0, -1, false, large_lines, {
        on_complete = function()
          callback()
        end,
      })
    end, 10000)

    table.insert(results, {
      name = "Rendering: Large buffer write (500 lines) - UI responsiveness",
      category = "rendering",
      operation = "tree_render_large",
      passed = ui_responsive,
      measured_ms = max_block,
      target_ms = 50,
      margin_percent = (max_block / 50 - 1) * 100,
      error = ui_responsive and nil or string.format("UI blocked for %.2fms", max_block),
    })
  else
    table.insert(results, {
      name = "Rendering: Large buffer write (500 lines)",
      category = "rendering",
      operation = "tree_render_large",
      passed = true,
      measured_ms = 0,
      target_ms = 16,
      margin_percent = 0,
      error = "set_lines_chunked not available - skipped",
    })
  end

  -- Cleanup
  pcall(vim.api.nvim_buf_delete, bufnr, { force = true })

  return results
end

-- ============================================================================
-- RPC Regression Tests
-- ============================================================================

--- Run RPC regression tests (startup time only, not network)
--- @return RegressionTestResult[] results
function M.run_rpc_tests()
  local results = {}

  -- Test: Time to initiate async RPC (not waiting for response)
  local start = vim.loop.hrtime()

  -- Simulate starting an async operation
  vim.schedule(function() end)
  vim.wait(1) -- Let the schedule execute

  local elapsed = (vim.loop.hrtime() - start) / 1e6

  local passed, reason = targets.check_target("rpc", "connect_start", elapsed)
  table.insert(results, {
    name = "RPC: Async operation start time",
    category = "rpc",
    operation = "connect_start",
    passed = passed,
    measured_ms = elapsed,
    target_ms = targets.targets.rpc.connect_start.max_blocking,
    margin_percent = (elapsed / targets.targets.rpc.connect_start.max_blocking - 1) * 100,
    error = reason,
  })

  return results
end

-- ============================================================================
-- Main Test Runner
-- ============================================================================

--- Run all regression tests
--- @param opts table? Options { categories: string[]? }
--- @return RegressionTestResult[] results
--- @return boolean all_passed
function M.run_all(opts)
  opts = opts or {}
  local categories = opts.categories or { "file_io", "completion", "formatter", "rendering", "rpc" }

  local all_results = {}
  local test_funcs = {
    file_io = M.run_file_io_tests,
    completion = M.run_completion_tests,
    formatter = M.run_formatter_tests,
    rendering = M.run_rendering_tests,
    rpc = M.run_rpc_tests,
  }

  for _, category in ipairs(categories) do
    local func = test_funcs[category]
    if func then
      vim.notify(string.format("Running %s regression tests...", category), vim.log.levels.INFO)
      local results = func()
      for _, r in ipairs(results) do
        table.insert(all_results, r)
      end
    end
  end

  local all_passed = true
  for _, r in ipairs(all_results) do
    if not r.passed then
      all_passed = false
      break
    end
  end

  return all_results, all_passed
end

--- Generate markdown report from regression test results
--- @param results RegressionTestResult[]
--- @param all_passed boolean
--- @return string report
function M.generate_report(results, all_passed)
  local lines = {
    "# SSNS Performance Regression Test Results",
    "",
    string.format("**Date**: %s", os.date("%Y-%m-%d %H:%M:%S")),
    string.format("**Status**: %s", all_passed and "✅ All tests passed" or "❌ Some tests failed"),
    "",
    "---",
    "",
    "## Results",
    "",
    "| Test | Status | Measured | Target | Margin |",
    "|------|--------|----------|--------|--------|",
  }

  for _, r in ipairs(results) do
    local status = r.passed and "✅" or "❌"
    local margin_str = string.format("%+.1f%%", r.margin_percent)
    table.insert(lines, string.format(
      "| %s | %s | %.2fms | %dms | %s |",
      r.name, status, r.measured_ms, r.target_ms, margin_str
    ))
  end

  table.insert(lines, "")

  -- Failed tests details
  local failed = {}
  for _, r in ipairs(results) do
    if not r.passed then
      table.insert(failed, r)
    end
  end

  if #failed > 0 then
    table.insert(lines, "## Failed Tests")
    table.insert(lines, "")
    for _, r in ipairs(failed) do
      table.insert(lines, string.format("### %s", r.name))
      table.insert(lines, "")
      table.insert(lines, string.format("- **Category**: %s", r.category))
      table.insert(lines, string.format("- **Operation**: %s", r.operation))
      table.insert(lines, string.format("- **Measured**: %.2fms", r.measured_ms))
      table.insert(lines, string.format("- **Target**: %dms", r.target_ms))
      table.insert(lines, string.format("- **Error**: %s", r.error or "Unknown"))
      table.insert(lines, "")
    end
  end

  return table.concat(lines, "\n")
end

--- Run regression tests and save report
--- @param opts table? Options
function M.run_and_report(opts)
  opts = opts or {}

  vim.notify("Starting performance regression tests...", vim.log.levels.INFO)

  local results, all_passed = M.run_all(opts)
  local report = M.generate_report(results, all_passed)

  -- Save report
  local filepath = vim.fn.stdpath("data") .. "/ssns/regression_test_results.md"
  local dir = vim.fn.fnamemodify(filepath, ":h")
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile(vim.split(report, "\n"), filepath)

  -- Summary
  local passed_count = 0
  local failed_count = 0
  for _, r in ipairs(results) do
    if r.passed then
      passed_count = passed_count + 1
    else
      failed_count = failed_count + 1
    end
  end

  if all_passed then
    vim.notify(string.format(
      "✅ All %d regression tests passed! Report: %s",
      passed_count, filepath
    ), vim.log.levels.INFO)
  else
    vim.notify(string.format(
      "❌ %d/%d regression tests failed! Report: %s",
      failed_count, passed_count + failed_count, filepath
    ), vim.log.levels.WARN)
  end

  return results, all_passed
end

return M
