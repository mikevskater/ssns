--- SSNS Testing Framework
--- Provides automated testing for IntelliSense/autocomplete features
local M = {}

-- Module dependencies
local runner = require("nvim-ssns.testing.runner")
local reporter = require("nvim-ssns.testing.reporter")
local utils = require("nvim-ssns.testing.utils")
local unit_runner = require("nvim-ssns.testing.unit_runner")

--- Default configuration
M.config = {
  test_file = vim.fn.stdpath("data") .. "/nvim-ssns/roadmap/phase-10/test_queries.sql",
  output_dir = vim.fn.stdpath("data") .. "/nvim-ssns/test_results",

  -- Connection configs by database type (ConnectionData structures)
  connections = {
    sqlserver = {
      type = "sqlserver",
      server = {
        host = ".",
        instance = "SQLEXPRESS",
      },
      auth = {
        type = "windows",
        password = "",
        username = ""
      },
    },
    -- Future: Add other database types
    -- postgres = {
    --   type = "postgres",
    --   server = { host = "localhost", port = 5432 },
    --   auth = { type = "password", username = "postgres", password = "" }
    -- },
    -- mysql = {
    --   type = "mysql",
    --   server = { host = "localhost", port = 3306 },
    --   auth = { type = "password", username = "root", password = "" }
    -- },
    -- sqlite = {
    --   type = "sqlite",
    --   server = { database = "./test.db" }
    -- },
  },

  -- Default connection type for tests
  default_connection_type = "sqlserver",
}

--- Initialize the testing framework
--- @param opts table|nil Optional configuration overrides
function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})
end

--- Run all tests in the test file
--- @param opts table|nil Optional run configuration
--- @return table Test results
function M.run_all_tests(opts)
  opts = opts or {}

  -- Run all tests
  local results = runner.run_all_tests(opts)

  if #results == 0 then
    vim.notify("No test results to report", vim.log.levels.WARN)
    return results
  end

  -- Display results
  reporter.display_results(results)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. "/nvim-ssns/test_results.md"
  local success = reporter.write_markdown(results, output_path)

  if success then
    vim.notify(string.format("Test results written to: %s", output_path), vim.log.levels.INFO)
  else
    vim.notify("Failed to write test results to file", vim.log.levels.ERROR)
  end

  return results
end

--- Run tests in a specific category folder
--- @param category_folder string Category folder name (e.g., "01_schema_table_qualification")
--- @param opts table|nil Optional run configuration
--- @return table Test results
function M.run_category_tests(category_folder, opts)
  opts = opts or {}

  vim.notify(string.format("Running tests for category: %s", category_folder), vim.log.levels.INFO)

  -- Run category tests via runner
  local results = runner.run_category_tests(category_folder, opts)

  if #results == 0 then
    vim.notify(string.format("No tests found for category: %s", category_folder), vim.log.levels.WARN)
    return results
  end

  -- Display results
  reporter.display_results(results)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. "/nvim-ssns/test_results.md"
  local success = reporter.write_markdown(results, output_path)

  if success then
    vim.notify(string.format("Test results written to: %s", output_path), vim.log.levels.INFO)
  else
    vim.notify("Failed to write test results to file", vim.log.levels.ERROR)
  end

  return results
end

--- Run a specific test by number
--- @param test_number number The test number to run
--- @param opts table|nil Optional run configuration
--- @return table Test result
function M.run_test(test_number, opts)
  opts = opts or {}

  -- Find test by number
  local test_path = runner.find_test_by_number(test_number)

  if not test_path then
    vim.notify(string.format("Test #%d not found", test_number), vim.log.levels.ERROR)
    return {}
  end

  vim.notify(string.format("Running test #%d...", test_number), vim.log.levels.INFO)

  -- Run single test
  local result = runner.run_single_test(test_path, opts)

  -- Wrap in array for reporter
  local results = { result }

  -- Display results
  reporter.display_results(results)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. string.format("/nvim-ssns/test_%d_result.md", test_number)
  local success = reporter.write_markdown(results, output_path)

  if success then
    vim.notify(string.format("Test result written to: %s", output_path), vim.log.levels.INFO)
  end

  return result
end

--- Run multiple tests by their numbers
--- @param test_numbers number[] Array of test numbers to run
--- @param opts table|nil Optional run configuration
--- @return table Test results array
function M.run_tests(test_numbers, opts)
  opts = opts or {}

  if not test_numbers or #test_numbers == 0 then
    vim.notify("No test numbers provided", vim.log.levels.ERROR)
    return {}
  end

  vim.notify(string.format("Running %d tests: %s", #test_numbers, table.concat(test_numbers, ", ")), vim.log.levels.INFO)

  local results = {}

  for i, test_number in ipairs(test_numbers) do
    -- Find test by number
    local test_path = runner.find_test_by_number(test_number)

    if not test_path then
      vim.notify(string.format("Test #%d not found, skipping", test_number), vim.log.levels.WARN)
      table.insert(results, {
        test_number = test_number,
        passed = false,
        error = "Test not found",
      })
    else
      -- Progress indicator
      if i % 5 == 0 or i == 1 then
        vim.notify(string.format("Running test %d/%d (#%d)...", i, #test_numbers, test_number), vim.log.levels.INFO)
      end

      -- Run single test
      local result = runner.run_single_test(test_path, opts)
      table.insert(results, result)
    end
  end

  -- Display results
  reporter.display_results(results)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. "/nvim-ssns/test_batch_results.md"
  local success = reporter.write_markdown(results, output_path)

  if success then
    vim.notify(string.format("Test results written to: %s", output_path), vim.log.levels.INFO)
  end

  return results
end

--- Run tests filtered by type
--- @param completion_type string The completion type (table, column, schema, etc.)
--- @param opts table|nil Optional run configuration
--- @return table Test results
function M.run_tests_by_type(completion_type, opts)
  opts = opts or {}

  vim.notify(string.format("Running tests for type: %s", completion_type), vim.log.levels.INFO)

  -- Run tests filtered by type
  local results = runner.run_tests_by_type(completion_type, opts)

  if #results == 0 then
    vim.notify(string.format("No tests found for type: %s", completion_type), vim.log.levels.WARN)
    return results
  end

  -- Display results
  reporter.display_results(results)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. string.format("/nvim-ssns/test_results_%s.md", completion_type)
  local success = reporter.write_markdown(results, output_path)

  if success then
    vim.notify(string.format("Test results written to: %s", output_path), vim.log.levels.INFO)
  else
    vim.notify("Failed to write test results to file", vim.log.levels.ERROR)
  end

  return results
end

--- Run tests for a specific database type
--- @param database_type string The database type (sqlserver, postgres, mysql, sqlite)
--- @param opts table|nil Optional run configuration
--- @return table Test results
function M.run_tests_by_database(database_type, opts)
  opts = opts or {}

  vim.notify(string.format("Running tests for database type: %s", database_type), vim.log.levels.INFO)

  -- Scan for all test files
  local all_test_files = utils.scan_test_folders()

  -- Filter by database type
  local filtered_files = {}
  for _, test_file in ipairs(all_test_files) do
    if test_file.database_type == database_type then
      table.insert(filtered_files, test_file)
    end
  end

  if #filtered_files == 0 then
    vim.notify(string.format("No tests found for database type: %s", database_type), vim.log.levels.WARN)
    return {}
  end

  vim.notify(string.format("Found %d tests for %s", #filtered_files, database_type), vim.log.levels.INFO)

  local results = {}

  -- Run each test
  for i, test_file in ipairs(filtered_files) do
    if i % 10 == 0 or i == 1 then
      vim.notify(string.format("Running test %d/%d...", i, #filtered_files), vim.log.levels.INFO)
    end

    local result = runner.run_single_test(test_file.path, vim.tbl_extend("force", opts, { database_type = test_file.database_type }))
    result.category = test_file.category
    result.name = test_file.name
    result.database_type = test_file.database_type
    table.insert(results, result)
  end

  -- Display results
  reporter.display_results(results)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. string.format("/nvim-ssns/test_results_%s.md", database_type)
  local success = reporter.write_markdown(results, output_path)

  if success then
    vim.notify(string.format("Test results written to: %s", output_path), vim.log.levels.INFO)
  else
    vim.notify("Failed to write test results to file", vim.log.levels.ERROR)
  end

  return results
end

--- Run all unit tests (tokenizer + parser)
--- @param opts table|nil Optional configuration {type?: string}
--- @return table results {total, passed, failed, results: table[]}
function M.run_unit_tests(opts)
  opts = opts or {}

  vim.notify("Running unit tests...", vim.log.levels.INFO)

  local results = unit_runner.run_all(opts)

  if results.total == 0 then
    vim.notify("No unit tests found", vim.log.levels.WARN)
    return results
  end

  -- Display results
  reporter.display_unit_results(results)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. "/nvim-ssns/unit_test_results.md"
  local success = reporter.write_unit_markdown(results, output_path)

  if success then
    vim.notify(string.format("Unit test results written to: %s", output_path), vim.log.levels.INFO)
  end

  return results
end

--- Run only tokenizer tests
--- @param opts table|nil Optional configuration
--- @return table results
function M.run_tokenizer_tests(opts)
  opts = opts or {}
  opts.type = "tokenizer"

  vim.notify("Running tokenizer tests...", vim.log.levels.INFO)
  return M.run_unit_tests(opts)
end

--- Run only parser tests
--- @param opts table|nil Optional configuration
--- @return table results
function M.run_parser_tests(opts)
  opts = opts or {}
  opts.type = "parser"

  vim.notify("Running parser tests...", vim.log.levels.INFO)
  return M.run_unit_tests(opts)
end

--- Run a specific unit test by ID
--- @param test_id number The test ID (e.g., 1001 for tokenizer, 2001 for parser)
--- @param opts table|nil Optional configuration
--- @return table|nil result Test result or nil if not found
function M.run_unit_test(test_id, opts)
  opts = opts or {}

  vim.notify(string.format("Running unit test #%d...", test_id), vim.log.levels.INFO)

  local result = unit_runner.run_by_id(test_id)

  if not result then
    vim.notify(string.format("Unit test #%d not found", test_id), vim.log.levels.ERROR)
    return nil
  end

  -- Display result
  local status = result.passed and "PASS" or "FAIL"
  vim.notify(string.format("[%s] #%d: %s (%.2fms)", status, result.id, result.name, result.duration_ms),
    result.passed and vim.log.levels.INFO or vim.log.levels.WARN)

  if not result.passed and result.error then
    vim.notify(string.format("  Error: %s", result.error), vim.log.levels.ERROR)
  end

  return result
end

--- Run a range of unit tests by ID
--- @param start_id number Starting test ID
--- @param end_id number Ending test ID
--- @param opts table|nil Optional configuration
--- @return table results {total, passed, failed, results: table[]}
function M.run_unit_tests_by_id_range(start_id, end_id, opts)
  opts = opts or {}

  vim.notify(string.format("Running unit tests #%d - #%d...", start_id, end_id), vim.log.levels.INFO)

  local results = unit_runner.run_by_id_range(start_id, end_id)

  if results.total == 0 then
    vim.notify(string.format("No unit tests found in range #%d - #%d", start_id, end_id), vim.log.levels.WARN)
    return results
  end

  -- Display results
  reporter.display_unit_results(results)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. string.format("/nvim-ssns/unit_test_results_%d_%d.md", start_id, end_id)
  local success = reporter.write_unit_markdown(results, output_path)

  if success then
    vim.notify(string.format("Unit test results written to: %s", output_path), vim.log.levels.INFO)
  end

  return results
end

--- Run IntelliSense provider tests
--- @param opts table|nil Optional configuration {provider?: string}
--- @return table results {total, passed, failed, results: table[]}
function M.run_provider_tests(opts)
  opts = opts or {}

  local filter_msg = opts.provider and string.format(" (provider: %s)", opts.provider) or ""
  vim.notify(string.format("Running provider tests%s...", filter_msg), vim.log.levels.INFO)

  -- Build filter options
  local filter_opts = {}
  if opts.provider then
    filter_opts.type = opts.provider
  else
    filter_opts.type = "provider"
  end

  local results = unit_runner.run_all(filter_opts)

  if results.total == 0 then
    vim.notify("No provider tests found", vim.log.levels.WARN)
    return results
  end

  -- Display results
  reporter.display_unit_results(results)

  -- Write markdown report
  local suffix = opts.provider and string.format("_provider_%s", opts.provider) or "_providers"
  local output_path = vim.fn.stdpath("data") .. string.format("/nvim-ssns/unit_test_results%s.md", suffix)
  local success = reporter.write_unit_markdown(results, output_path)

  if success then
    vim.notify(string.format("Provider test results written to: %s", output_path), vim.log.levels.INFO)
  end

  return results
end

--- Run IntelliSense context tests
--- @param opts table|nil Optional configuration {context_type?: string}
--- @return table results {total, passed, failed, results: table[]}
function M.run_context_tests(opts)
  opts = opts or {}

  local filter_msg = opts.context_type and string.format(" (type: %s)", opts.context_type) or ""
  vim.notify(string.format("Running context tests%s...", filter_msg), vim.log.levels.INFO)

  -- Build filter options
  local filter_opts = {}
  if opts.context_type then
    filter_opts.type = opts.context_type
  else
    filter_opts.type = "context"
  end

  local results = unit_runner.run_all(filter_opts)

  if results.total == 0 then
    vim.notify("No context tests found", vim.log.levels.WARN)
    return results
  end

  -- Display results
  reporter.display_unit_results(results)

  -- Write markdown report
  local suffix = opts.context_type and string.format("_context_%s", opts.context_type) or "_context"
  local output_path = vim.fn.stdpath("data") .. string.format("/nvim-ssns/unit_test_results%s.md", suffix)
  local success = reporter.write_unit_markdown(results, output_path)

  if success then
    vim.notify(string.format("Context test results written to: %s", output_path), vim.log.levels.INFO)
  end

  return results
end

--- Run all IntelliSense tests (providers + context + utilities)
--- @param opts table|nil Optional configuration
--- @return table results {total, passed, failed, results: table[]}
function M.run_intellisense_tests(opts)
  opts = opts or {}

  vim.notify("Running all IntelliSense tests (providers, context, utilities)...", vim.log.levels.INFO)

  -- Run all tests and aggregate results
  local all_results = {
    total = 0,
    passed = 0,
    failed = 0,
    results = {}
  }

  -- Run provider tests
  local provider_results = unit_runner.run_all({ type = "provider" })
  all_results.total = all_results.total + provider_results.total
  all_results.passed = all_results.passed + provider_results.passed
  all_results.failed = all_results.failed + provider_results.failed
  for _, result in ipairs(provider_results.results) do
    table.insert(all_results.results, result)
  end

  -- Run context tests
  local context_results = unit_runner.run_all({ type = "context" })
  all_results.total = all_results.total + context_results.total
  all_results.passed = all_results.passed + context_results.passed
  all_results.failed = all_results.failed + context_results.failed
  for _, result in ipairs(context_results.results) do
    table.insert(all_results.results, result)
  end

  -- Run utility tests (fuzzy_matcher, type_compatibility, fk_graph)
  local utility_types = { "fuzzy_matcher", "type_compatibility", "fk_graph" }
  for _, util_type in ipairs(utility_types) do
    local util_results = unit_runner.run_all({ type = util_type })
    all_results.total = all_results.total + util_results.total
    all_results.passed = all_results.passed + util_results.passed
    all_results.failed = all_results.failed + util_results.failed
    for _, result in ipairs(util_results.results) do
      table.insert(all_results.results, result)
    end
  end

  if all_results.total == 0 then
    vim.notify("No IntelliSense tests found", vim.log.levels.WARN)
    return all_results
  end

  -- Display results
  reporter.display_unit_results(all_results)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. "/nvim-ssns/unit_test_results_intellisense.md"
  local success = reporter.write_unit_markdown(all_results, output_path)

  if success then
    vim.notify(string.format("IntelliSense test results written to: %s", output_path), vim.log.levels.INFO)
  end

  return all_results
end

--- Run formatter tests
--- @param opts table|nil Optional configuration
--- @return table results {total, passed, failed, results: table[]}
function M.run_formatter_tests(opts)
  opts = opts or {}

  vim.notify("Running formatter tests...", vim.log.levels.INFO)

  local results = unit_runner.run_all({ type = "formatter" })

  if results.total == 0 then
    vim.notify("No formatter tests found", vim.log.levels.WARN)
    return results
  end

  -- Display results
  reporter.display_unit_results(results)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. "/nvim-ssns/formatter_test_results.md"
  local success = reporter.write_unit_markdown(results, output_path)

  if success then
    vim.notify(string.format("Formatter test results written to: %s", output_path), vim.log.levels.INFO)
  end

  return results
end

--- Run async integration tests
--- @param opts table|nil Optional configuration
--- @return table results {total, passed, failed, results: table[]}
function M.run_async_integration_tests(opts)
  opts = opts or {}

  vim.notify("Running async integration tests...", vim.log.levels.INFO)

  local async_runner = require("nvim-ssns.testing.async_integration_runner")
  local results = async_runner.run_all_tests(opts)

  if not results or results.total == 0 then
    vim.notify("No async integration tests found or results returned", vim.log.levels.WARN)
    return results or { total = 0, passed = 0, failed = 0, results = {} }
  end

  -- Display results
  local executed = results.total - (results.skipped or 0)
  local pass_rate = executed > 0 and (results.passed / executed * 100) or 0
  local skip_msg = results.skipped and results.skipped > 0
      and string.format(", %d skipped", results.skipped) or ""
  vim.notify(string.format("Async Integration Tests: %d/%d passed (%.1f%%)%s",
    results.passed, executed, pass_rate, skip_msg),
    results.failed > 0 and vim.log.levels.WARN or vim.log.levels.INFO)

  -- Write markdown report
  local output_path = vim.fn.stdpath("data") .. "/nvim-ssns/async_integration_test_results.md"
  local success = reporter.write_unit_markdown(results, output_path)

  if success then
    vim.notify(string.format("Async integration test results written to: %s", output_path), vim.log.levels.INFO)
  end

  return results
end

--- Run a specific async integration test by ID
--- @param test_id number The test ID (10001-10999)
--- @param opts table|nil Optional configuration
--- @return table|nil result Test result or nil if not found
function M.run_async_integration_test(test_id, opts)
  opts = opts or {}

  vim.notify(string.format("Running async integration test #%d...", test_id), vim.log.levels.INFO)

  local async_runner = require("nvim-ssns.testing.async_integration_runner")
  local all_tests = async_runner.scan_tests()

  -- Find the test by ID
  local test_data = nil
  for _, test in ipairs(all_tests) do
    if test.id == test_id then
      test_data = test
      break
    end
  end

  if not test_data then
    vim.notify(string.format("Async integration test #%d not found", test_id), vim.log.levels.ERROR)
    return nil
  end

  local result = async_runner.run_single_test(test_data, opts)

  -- Display result
  local status = result.passed and "PASS" or "FAIL"
  vim.notify(string.format("[%s] #%d: %s (%.2fms)", status, result.id, result.name, result.duration_ms),
    result.passed and vim.log.levels.INFO or vim.log.levels.WARN)

  if not result.passed and result.error then
    vim.notify(string.format("  Error: %s", result.error), vim.log.levels.ERROR)
  end

  return result
end

--- Expose submodules for direct access
M.runner = runner
M.reporter = reporter
M.utils = utils
M.unit_runner = unit_runner
M.async_integration_runner = require("nvim-ssns.testing.async_integration_runner")

return M
