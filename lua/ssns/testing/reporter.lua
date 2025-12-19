--- Test reporter module
--- Formats and displays test results
local M = {}

local utils = require("ssns.testing.utils")

-- Track incremental file state
local incremental_state = {
  file_path = nil,
  started = false,
  results_count = 0,
}

--- Format a single test result
--- @param result table Test result object
--- @return string formatted Formatted result as markdown
function M.format_result(result)
  local lines = {}

  -- Status indicator
  local status = result.passed and "✓" or "✗"
  local status_text = result.passed and "PASS" or "FAIL"

  -- Header
  table.insert(lines, string.format("### %s Test #%d: %s",
    status,
    result.test_number or 0,
    result.description or "Unknown"))

  -- Basic info
  table.insert(lines, string.format("- **Status**: %s", status_text))
  table.insert(lines, string.format("- **Database**: %s", result.database or "N/A"))
  table.insert(lines, string.format("- **Expected Type**: %s", result.expected_type or "N/A"))
  table.insert(lines, string.format("- **Duration**: %.2fms", result.duration_ms or 0))
  table.insert(lines, string.format("- **Category**: %s", utils.clean_category_name(result.category or "uncategorized")))

  -- Error details (if failed)
  if result.error then
    table.insert(lines, "")
    table.insert(lines, "**Error:**")
    table.insert(lines, "```")
    table.insert(lines, result.error)
    table.insert(lines, "```")
  end

  -- Comparison details
  if result.comparison then
    table.insert(lines, "")
    table.insert(lines, "**Results:**")
    local expected_count = result.comparison.expected_count or 0
    local actual_count = result.comparison.actual_count or 0
    if type(expected_count) ~= "number" then expected_count = tonumber(expected_count) or 0 end
    if type(actual_count) ~= "number" then actual_count = tonumber(actual_count) or 0 end
    table.insert(lines, string.format("- Expected: %d items", expected_count))
    table.insert(lines, string.format("- Actual: %d items", actual_count))

    if #result.comparison.missing > 0 then
      table.insert(lines, "")
      table.insert(lines, "**Missing Items:**")
      table.insert(lines, string.format("- %s", utils.format_item_list(result.comparison.missing)))
    end

    if #result.comparison.unexpected > 0 then
      table.insert(lines, "")
      table.insert(lines, "**Unexpected Items:**")
      table.insert(lines, string.format("- %s", utils.format_item_list(result.comparison.unexpected)))
    end

    -- Always show actual items for debugging failed tests
    if not result.passed and result.comparison.actual_items and #result.comparison.actual_items > 0 then
      table.insert(lines, "")
      table.insert(lines, "**Actual Items:**")
      table.insert(lines, string.format("- %s", utils.format_item_list(result.comparison.actual_items, 20)))
    end
  end

  table.insert(lines, "")
  return table.concat(lines, "\n")
end

--- Create summary table by category
--- @param results table[] Array of test results
--- @return string markdown Markdown table
function M.create_summary_table(results)
  -- Group results by category
  local by_category = {}
  for _, result in ipairs(results) do
    local category = result.category or "uncategorized"
    if not by_category[category] then
      by_category[category] = { total = 0, passed = 0, failed = 0 }
    end
    by_category[category].total = by_category[category].total + 1
    if result.passed then
      by_category[category].passed = by_category[category].passed + 1
    else
      by_category[category].failed = by_category[category].failed + 1
    end
  end

  -- Sort categories
  local categories = {}
  for category, _ in pairs(by_category) do
    table.insert(categories, category)
  end
  table.sort(categories)

  -- Build markdown table
  local lines = {}
  table.insert(lines, "| Category | Total | Passed | Failed | Pass Rate |")
  table.insert(lines, "|----------|-------|--------|--------|-----------|")

  for _, category in ipairs(categories) do
    local stats = by_category[category]
    local pass_rate = stats.total > 0 and (stats.passed / stats.total * 100) or 0

    table.insert(lines, string.format("| %s | %d | %d | %d | %.1f%% |",
      utils.clean_category_name(category),
      stats.total,
      stats.passed,
      stats.failed,
      pass_rate))
  end

  return table.concat(lines, "\n")
end

--- Write test results to markdown file
--- @param results table[] Array of test results
--- @param output_path string Output file path
--- @return boolean success True if write succeeded
function M.write_markdown(results, output_path)
  -- Ensure output directory exists
  local output_dir = vim.fn.fnamemodify(output_path, ":h")
  vim.fn.mkdir(output_dir, "p")

  -- Calculate summary statistics
  local total = #results
  local passed = 0
  local failed = 0
  local total_duration = 0

  for _, result in ipairs(results) do
    if result.passed then
      passed = passed + 1
    else
      failed = failed + 1
    end
    total_duration = total_duration + (result.duration_ms or 0)
  end

  local pass_rate = total > 0 and (passed / total * 100) or 0

  -- Build markdown content
  local lines = {}

  -- Header
  table.insert(lines, "# SSNS IntelliSense Test Results")
  table.insert(lines, "")
  table.insert(lines, string.format("**Generated**: %s", os.date("%Y-%m-%d %H:%M:%S")))
  table.insert(lines, "")

  -- Summary section
  table.insert(lines, "## Summary")
  table.insert(lines, "")
  table.insert(lines, string.format("- **Total Tests**: %d", total))
  table.insert(lines, string.format("- **Passed**: %d", passed))
  table.insert(lines, string.format("- **Failed**: %d", failed))
  table.insert(lines, string.format("- **Pass Rate**: %.1f%%", pass_rate))
  table.insert(lines, string.format("- **Total Duration**: %.2fms", total_duration))
  table.insert(lines, string.format("- **Average Duration**: %.2fms", total > 0 and (total_duration / total) or 0))
  table.insert(lines, "")

  -- Results by category
  table.insert(lines, "## Results by Category")
  table.insert(lines, "")
  table.insert(lines, M.create_summary_table(results))
  table.insert(lines, "")

  -- Detailed results
  table.insert(lines, "## Detailed Results")
  table.insert(lines, "")

  -- Group by category for organized output
  local by_category = {}
  for _, result in ipairs(results) do
    local category = result.category or "uncategorized"
    if not by_category[category] then
      by_category[category] = {}
    end
    table.insert(by_category[category], result)
  end

  -- Sort categories
  local categories = {}
  for category, _ in pairs(by_category) do
    table.insert(categories, category)
  end
  table.sort(categories)

  -- Output results by category
  for _, category in ipairs(categories) do
    table.insert(lines, string.format("### %s", utils.clean_category_name(category)))
    table.insert(lines, "")

    local category_results = by_category[category]
    -- Sort by test number
    table.sort(category_results, function(a, b)
      return (a.test_number or 0) < (b.test_number or 0)
    end)

    for _, result in ipairs(category_results) do
      table.insert(lines, M.format_result(result))
    end
  end

  -- Failed tests summary (if any)
  if failed > 0 then
    table.insert(lines, "")
    table.insert(lines, "## Failed Tests Summary")
    table.insert(lines, "")

    local failed_tests = {}
    for _, result in ipairs(results) do
      if not result.passed then
        table.insert(failed_tests, result)
      end
    end

    -- Sort by test number
    table.sort(failed_tests, function(a, b)
      return (a.test_number or 0) < (b.test_number or 0)
    end)

    for _, result in ipairs(failed_tests) do
      table.insert(lines, string.format("- **Test #%s**: %s (Category: %s)",
        tostring(result.test_number or "?"),
        result.description or "Unknown",
        utils.clean_category_name(result.category or "uncategorized")))

      if result.error then
        table.insert(lines, string.format("  - Error: %s", result.error:gsub("\n", " ")))
      elseif result.comparison then
        if #result.comparison.missing > 0 then
          table.insert(lines, string.format("  - Missing: %s", utils.format_item_list(result.comparison.missing, 5)))
        end
        if #result.comparison.unexpected > 0 then
          table.insert(lines, string.format("  - Unexpected: %s", utils.format_item_list(result.comparison.unexpected, 5)))
        end
      end
    end
  end

  -- Write to file
  local content = table.concat(lines, "\n")
  local file = io.open(output_path, "w")
  if not file then
    vim.notify(string.format("Failed to open file for writing: %s", output_path), vim.log.levels.ERROR)
    return false
  end

  file:write(content)
  file:close()

  return true
end

--- Display test results in Neovim messages
--- @param results table[] Array of test results
function M.display_results(results)
  local total = #results
  local passed = 0
  local failed = 0

  for _, result in ipairs(results) do
    if result.passed then
      passed = passed + 1
    else
      failed = failed + 1
    end
  end

  local pass_rate = total > 0 and (passed / total * 100) or 0

  -- Display summary
  vim.notify(string.format("===== Test Results ====="), vim.log.levels.INFO)
  vim.notify(string.format("Total: %d | Passed: %d | Failed: %d | Pass Rate: %.1f%%",
    total, passed, failed, pass_rate), vim.log.levels.INFO)

  -- Display failed tests
  if failed > 0 then
    vim.notify(string.format("\nFailed Tests:"), vim.log.levels.WARN)

    local failed_tests = {}
    for _, result in ipairs(results) do
      if not result.passed then
        table.insert(failed_tests, result)
      end
    end

    -- Sort by test number
    table.sort(failed_tests, function(a, b)
      return (a.test_number or 0) < (b.test_number or 0)
    end)

    for _, result in ipairs(failed_tests) do
      local test_num = result.test_number or 0
      if type(test_num) ~= "number" then test_num = tonumber(test_num) or 0 end
      local msg = string.format("  Test #%d: %s", test_num, result.description or "Unknown")

      if result.error then
        msg = msg .. string.format("\n    Error: %s", result.error:gsub("\n", " "))
      elseif result.comparison then
        if #result.comparison.missing > 0 then
          msg = msg .. string.format("\n    Missing: %s", utils.format_item_list(result.comparison.missing, 5))
        end
        if #result.comparison.unexpected > 0 then
          msg = msg .. string.format("\n    Unexpected: %s", utils.format_item_list(result.comparison.unexpected, 5))
        end
      end

      vim.notify(msg, vim.log.levels.WARN)
    end
  end

  vim.notify("========================", vim.log.levels.INFO)
end

--- Create a concise summary string
--- @param results table[] Array of test results
--- @return string summary Summary string
function M.create_summary(results)
  local total = #results
  local passed = 0
  local failed = 0

  for _, result in ipairs(results) do
    if result.passed then
      passed = passed + 1
    else
      failed = failed + 1
    end
  end

  local pass_rate = total > 0 and (passed / total * 100) or 0

  return string.format("Total: %d | Passed: %d | Failed: %d | Pass Rate: %.1f%%",
    total, passed, failed, pass_rate)
end

--- Format a single unit test result
--- @param result table Unit test result
--- @return string formatted Formatted result as markdown
function M.format_unit_result(result)
  local lines = {}
  local status = result.passed and "✓" or "✗"
  local status_text = result.passed and "PASS" or "FAIL"

  table.insert(lines, string.format("### %s Test #%d: %s", status, result.id, result.name))
  table.insert(lines, string.format("- **Status**: %s", status_text))
  table.insert(lines, string.format("- **Type**: %s", result.type))
  table.insert(lines, string.format("- **Duration**: %.2fms", result.duration_ms or 0))

  -- Show input SQL
  table.insert(lines, "")
  table.insert(lines, "**Input:**")
  table.insert(lines, "```sql")
  -- Handle input that might be a table (for async tests with complex inputs)
  local input_str = result.input
  if type(input_str) == "table" then
    input_str = vim.inspect(input_str)
  end
  table.insert(lines, input_str or "")
  table.insert(lines, "```")

  -- Show error if failed
  if not result.passed and result.error then
    table.insert(lines, "")
    table.insert(lines, "**Error:**")
    table.insert(lines, "```")
    table.insert(lines, result.error)
    table.insert(lines, "```")
  end

  table.insert(lines, "")
  return table.concat(lines, "\n")
end

--- Create summary table for unit tests by type (tokenizer/parser)
--- @param results table[] Array of unit test results
--- @return string markdown Markdown table
function M.create_unit_summary_table(results)
  -- Group by type (tokenizer, parser)
  local by_type = {}
  for _, result in ipairs(results) do
    local test_type = result.type or "unknown"
    if not by_type[test_type] then
      by_type[test_type] = { total = 0, passed = 0, failed = 0 }
    end
    by_type[test_type].total = by_type[test_type].total + 1
    if result.passed then
      by_type[test_type].passed = by_type[test_type].passed + 1
    else
      by_type[test_type].failed = by_type[test_type].failed + 1
    end
  end

  local lines = {}
  table.insert(lines, "| Type | Total | Passed | Failed | Pass Rate |")
  table.insert(lines, "|------|-------|--------|--------|-----------|")

  for test_type, stats in pairs(by_type) do
    local pass_rate = stats.total > 0 and (stats.passed / stats.total * 100) or 0
    table.insert(lines, string.format("| %s | %d | %d | %d | %.1f%% |",
      test_type, stats.total, stats.passed, stats.failed, pass_rate))
  end

  return table.concat(lines, "\n")
end

--- Write unit test results to markdown file
--- @param results table Unit test results {total, passed, failed, results: table[]}
--- @param output_path string Output file path
--- @return boolean success
function M.write_unit_markdown(results, output_path)
  -- Ensure output directory exists
  local output_dir = vim.fn.fnamemodify(output_path, ":h")
  vim.fn.mkdir(output_dir, "p")

  -- Extract results array
  local test_results = results.results or {}
  local total = results.total or #test_results
  local passed = results.passed or 0
  local failed = results.failed or 0
  local total_duration = 0

  for _, result in ipairs(test_results) do
    total_duration = total_duration + (result.duration_ms or 0)
  end

  local pass_rate = total > 0 and (passed / total * 100) or 0

  -- Build markdown content
  local lines = {}

  -- Header
  table.insert(lines, "# SSNS Unit Test Results")
  table.insert(lines, "")
  table.insert(lines, string.format("**Generated**: %s", os.date("%Y-%m-%d %H:%M:%S")))
  table.insert(lines, "")

  -- Summary section
  table.insert(lines, "## Summary")
  table.insert(lines, "")
  table.insert(lines, string.format("- **Total Tests**: %d", total))
  table.insert(lines, string.format("- **Passed**: %d", passed))
  table.insert(lines, string.format("- **Failed**: %d", failed))
  table.insert(lines, string.format("- **Pass Rate**: %.1f%%", pass_rate))
  table.insert(lines, string.format("- **Total Duration**: %.2fms", total_duration))
  table.insert(lines, string.format("- **Average Duration**: %.2fms", total > 0 and (total_duration / total) or 0))
  table.insert(lines, "")

  -- Results by type
  table.insert(lines, "## Results by Type")
  table.insert(lines, "")
  table.insert(lines, M.create_unit_summary_table(test_results))
  table.insert(lines, "")

  -- Detailed results
  table.insert(lines, "## Detailed Results")
  table.insert(lines, "")

  -- Group by type for organized output
  local by_type = {}
  for _, result in ipairs(test_results) do
    local test_type = result.type or "unknown"
    if not by_type[test_type] then
      by_type[test_type] = {}
    end
    table.insert(by_type[test_type], result)
  end

  -- Sort types
  local types = {}
  for test_type, _ in pairs(by_type) do
    table.insert(types, test_type)
  end
  table.sort(types)

  -- Output results by type
  for _, test_type in ipairs(types) do
    table.insert(lines, string.format("### %s Tests", test_type:gsub("^%l", string.upper)))
    table.insert(lines, "")

    local type_results = by_type[test_type]
    -- Sort by test ID
    table.sort(type_results, function(a, b)
      return (a.id or 0) < (b.id or 0)
    end)

    for _, result in ipairs(type_results) do
      table.insert(lines, M.format_unit_result(result))
    end
  end

  -- Failed tests summary (if any)
  if failed > 0 then
    table.insert(lines, "")
    table.insert(lines, "## Failed Tests Summary")
    table.insert(lines, "")

    local failed_tests = {}
    for _, result in ipairs(test_results) do
      if not result.passed then
        table.insert(failed_tests, result)
      end
    end

    -- Sort by test ID
    table.sort(failed_tests, function(a, b)
      return (a.id or 0) < (b.id or 0)
    end)

    for _, result in ipairs(failed_tests) do
      table.insert(lines, string.format("- **Test #%d**: %s (Type: %s)",
        result.id or "?",
        result.name or "Unknown",
        result.type or "unknown"))

      if result.error then
        table.insert(lines, string.format("  - Error: %s", result.error:gsub("\n", " ")))
      end
    end
  end

  -- Write to file
  local content = table.concat(lines, "\n")
  local file = io.open(output_path, "w")
  if not file then
    vim.notify(string.format("Failed to open file for writing: %s", output_path), vim.log.levels.ERROR)
    return false
  end

  file:write(content)
  file:close()

  return true
end

--- Display unit test results in Neovim messages
--- @param results table Unit test results
function M.display_unit_results(results)
  local total = results.total or #(results.results or {})
  local passed = results.passed or 0
  local failed = results.failed or 0
  local pass_rate = total > 0 and (passed / total * 100) or 0

  vim.notify("===== Unit Test Results =====", vim.log.levels.INFO)
  vim.notify(string.format("Total: %d | Passed: %d | Failed: %d | Pass Rate: %.1f%%",
    total, passed, failed, pass_rate), vim.log.levels.INFO)

  -- Show failed tests
  if failed > 0 and results.results then
    vim.notify("\nFailed Tests:", vim.log.levels.WARN)
    for _, result in ipairs(results.results) do
      if not result.passed then
        vim.notify(string.format("  #%d: %s (%s)", result.id, result.name, result.type), vim.log.levels.WARN)
        if result.error then
          vim.notify(string.format("    Error: %s", result.error:gsub("\n", " "):sub(1, 100)), vim.log.levels.WARN)
        end
      end
    end
  end

  vim.notify("==============================", vim.log.levels.INFO)
end

--- Start incremental test results file
--- @param output_path string Output file path
--- @param total_tests number Total number of tests to run
--- @return boolean success True if file was created
function M.start_incremental(output_path, total_tests)
  -- Ensure output directory exists
  local output_dir = vim.fn.fnamemodify(output_path, ":h")
  vim.fn.mkdir(output_dir, "p")

  -- Reset state
  incremental_state.file_path = output_path
  incremental_state.started = true
  incremental_state.results_count = 0

  -- Write header
  local file = io.open(output_path, "w")
  if not file then
    vim.notify(string.format("Failed to open file for writing: %s", output_path), vim.log.levels.ERROR)
    return false
  end

  file:write("# SSNS IntelliSense Test Results (Incremental)\n\n")
  file:write(string.format("**Started**: %s\n", os.date("%Y-%m-%d %H:%M:%S")))
  file:write(string.format("**Total Tests**: %d\n\n", total_tests))
  file:write("---\n\n")
  file:write("## Test Results (Live)\n\n")
  file:close()

  return true
end

--- Write a single test result incrementally
--- @param result table Test result object
--- @param test_index number Current test index (1-based)
--- @param total_tests number Total number of tests
--- @return boolean success True if write succeeded
function M.write_incremental_result(result, test_index, total_tests)
  if not incremental_state.started or not incremental_state.file_path then
    return false
  end

  local file = io.open(incremental_state.file_path, "a")
  if not file then
    return false
  end

  -- Write progress marker
  local status_icon = result.passed and "PASS" or "FAIL"
  local status_emoji = result.passed and "✓" or "✗"

  file:write(string.format("### [%d/%d] %s Test #%d: %s\n",
    test_index, total_tests,
    status_emoji,
    result.test_number or 0,
    result.description or "Unknown"))

  file:write(string.format("- **Status**: %s\n", status_icon))
  file:write(string.format("- **Category**: %s\n", utils.clean_category_name(result.category or "uncategorized")))
  file:write(string.format("- **Database**: %s\n", result.database or "N/A"))
  file:write(string.format("- **Duration**: %.2fms\n", result.duration_ms or 0))
  file:write(string.format("- **Timestamp**: %s\n", os.date("%H:%M:%S")))

  if result.error then
    file:write("\n**Error:**\n```\n")
    file:write(result.error)
    file:write("\n```\n")
  end

  if result.comparison then
    if #result.comparison.missing > 0 then
      file:write(string.format("\n**Missing**: %s\n", utils.format_item_list(result.comparison.missing, 10)))
    end
    if #result.comparison.unexpected > 0 then
      file:write(string.format("**Unexpected**: %s\n", utils.format_item_list(result.comparison.unexpected, 10)))
    end
  end

  file:write("\n---\n\n")
  file:close()

  incremental_state.results_count = incremental_state.results_count + 1

  return true
end

--- Finish incremental test results file with summary
--- @param results table[] Array of all test results
--- @return boolean success True if file was updated
function M.finish_incremental(results)
  if not incremental_state.started or not incremental_state.file_path then
    return false
  end

  local file = io.open(incremental_state.file_path, "a")
  if not file then
    return false
  end

  -- Calculate summary
  local total = #results
  local passed = 0
  local failed = 0
  local total_duration = 0

  for _, result in ipairs(results) do
    if result.passed then
      passed = passed + 1
    else
      failed = failed + 1
    end
    total_duration = total_duration + (result.duration_ms or 0)
  end

  local pass_rate = total > 0 and (passed / total * 100) or 0

  -- Write summary
  file:write("## Final Summary\n\n")
  file:write(string.format("**Completed**: %s\n\n", os.date("%Y-%m-%d %H:%M:%S")))
  file:write(string.format("- **Total Tests**: %d\n", total))
  file:write(string.format("- **Passed**: %d\n", passed))
  file:write(string.format("- **Failed**: %d\n", failed))
  file:write(string.format("- **Pass Rate**: %.1f%%\n", pass_rate))
  file:write(string.format("- **Total Duration**: %.2fms\n", total_duration))

  -- Write category summary table
  file:write("\n## Results by Category\n\n")
  file:write(M.create_summary_table(results))
  file:write("\n")

  -- Write failed tests summary
  if failed > 0 then
    file:write("\n## Failed Tests Summary\n\n")
    for _, result in ipairs(results) do
      if not result.passed then
        file:write(string.format("- **Test #%d**: %s (Category: %s)\n",
          result.test_number or 0,
          result.description or "Unknown",
          utils.clean_category_name(result.category or "uncategorized")))
      end
    end
  end

  file:close()

  -- Reset state
  incremental_state.started = false

  return true
end

--- Write a "currently running" marker for a test
--- @param test_info table Test info {number, description, category, path}
--- @param test_index number Current test index (1-based)
--- @param total_tests number Total number of tests
--- @return boolean success
function M.mark_test_running(test_info, test_index, total_tests)
  if not incremental_state.started or not incremental_state.file_path then
    return false
  end

  local file = io.open(incremental_state.file_path, "a")
  if not file then
    return false
  end

  file:write(string.format("### [%d/%d] RUNNING: Test #%d - %s\n",
    test_index, total_tests,
    test_info.number or 0,
    test_info.description or test_info.name or "Unknown"))
  file:write(string.format("- **Category**: %s\n", utils.clean_category_name(test_info.category or "uncategorized")))
  file:write(string.format("- **Path**: %s\n", test_info.path or "unknown"))
  file:write(string.format("- **Started**: %s\n\n", os.date("%H:%M:%S")))
  file:close()

  return true
end

return M
