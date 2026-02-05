--- SSNS Performance Benchmarks
--- Entry point for all benchmark and regression test functionality
---
--- Usage:
---   :SSNSBenchmarks          - Run all benchmarks
---   :SSNSBenchmarks file_io  - Run file I/O benchmarks only
---   :SSNSBenchmarks formatter - Run formatter benchmarks only
---   :SSNSRegressionTests     - Run performance regression tests
---   :SSNSLatencyTargets      - Show latency target documentation
local M = {}

local runner = require("nvim-ssns.testing.benchmarks.runner")
local async_benchmarks = require("nvim-ssns.testing.benchmarks.async_benchmarks")
local regression_tests = require("nvim-ssns.testing.benchmarks.regression_tests")
local latency_targets = require("nvim-ssns.testing.benchmarks.latency_targets")

--- Run all benchmarks
--- @param opts table? Options { iterations: number, warmup: number }
--- @return string report Markdown report
function M.run_all_benchmarks(opts)
  return async_benchmarks.run_all(opts)
end

--- Run benchmarks for a specific category
--- @param category string Category: "file_io", "formatter", "completion", "rendering"
--- @param opts table? Options
--- @return string report Markdown report
function M.run_category_benchmarks(category, opts)
  return async_benchmarks.run_category(category, opts)
end

--- Run performance regression tests
--- @param opts table? Options { categories: string[]? }
--- @return table results, boolean all_passed
function M.run_regression_tests(opts)
  return regression_tests.run_and_report(opts)
end

--- Get latency targets documentation
--- @return string report Markdown documentation
function M.get_latency_targets()
  return latency_targets.generate_targets_report()
end

--- Check if a specific operation meets its latency target
--- @param category string Category
--- @param operation string Operation
--- @param measured_ms number Measured time
--- @return boolean passes, string? reason
function M.check_target(category, operation, measured_ms)
  return latency_targets.check_target(category, operation, measured_ms)
end

--- Verify UI responsiveness during an async operation
--- @param operation_fn function Async operation
--- @param timeout_ms number? Timeout
--- @return boolean responsive, number max_block_time
function M.verify_ui_responsiveness(operation_fn, timeout_ms)
  return latency_targets.verify_ui_responsiveness(operation_fn, timeout_ms)
end

--- Setup Neovim commands for benchmarks
function M.setup_commands()
  -- Main benchmark command
  vim.api.nvim_create_user_command("SSNSBenchmarks", function(opts)
    local category = opts.args ~= "" and opts.args or nil
    if category then
      local valid_categories = { "file_io", "formatter", "completion", "rendering" }
      if not vim.tbl_contains(valid_categories, category) then
        vim.notify(
          string.format("Invalid category: %s. Valid: %s", category, table.concat(valid_categories, ", ")),
          vim.log.levels.ERROR
        )
        return
      end
      M.run_category_benchmarks(category)
    else
      M.run_all_benchmarks()
    end
  end, {
    nargs = "?",
    complete = function()
      return { "file_io", "formatter", "completion", "rendering" }
    end,
    desc = "Run SSNS async performance benchmarks",
  })

  -- Regression tests command
  vim.api.nvim_create_user_command("SSNSRegressionTests", function()
    M.run_regression_tests()
  end, {
    desc = "Run SSNS performance regression tests",
  })

  -- Latency targets command
  vim.api.nvim_create_user_command("SSNSLatencyTargets", function()
    local report = M.get_latency_targets()
    -- Create a scratch buffer to show the report
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, "filetype", "markdown")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(report, "\n"))
    vim.api.nvim_set_current_buf(bufnr)
  end, {
    desc = "Show SSNS async latency targets",
  })
end

return M
