-- Integration tests: Async Formatter Workflows
-- IDs: 10101-10150
-- Tests end-to-end async formatting behaviors including:
-- - Small vs large file async threshold
-- - Progress callbacks during formatting
-- - Format cancellation
-- - Buffer modification after async format

return {
  -- ============================================================================
  -- Basic async formatting
  -- ============================================================================
  {
    id = 10101,
    type = "async_integration",
    name = "Async format - small SQL uses sync path",
    description = "Verify small SQL is formatted synchronously (below threshold)",
    input_sql = "SELECT * FROM Employees WHERE EmployeeID = 1",
    expected = {
      formatted = true,
      output_contains = "SELECT",
      output_contains_2 = "FROM",
      output_contains_3 = "WHERE",
    },
    timeout_ms = 2000,
  },
  {
    id = 10102,
    type = "async_integration",
    name = "Async format - basic SELECT formatting",
    description = "Verify basic SELECT is formatted correctly",
    input_sql = "select * from employees where employeeid=1",
    expected = {
      formatted = true,
      case_corrected = true, -- Keywords should be uppercased
    },
    timeout_ms = 2000,
  },
  {
    id = 10103,
    type = "async_integration",
    name = "Async format - JOIN formatting",
    description = "Verify JOIN statement is formatted correctly",
    input_sql = "select e.FirstName,d.DepartmentName from Employees e inner join Departments d on e.DepartmentID=d.DepartmentID",
    expected = {
      formatted = true,
      output_contains = "INNER JOIN",
      output_contains_2 = "ON",
    },
    timeout_ms = 2000,
  },

  -- ============================================================================
  -- Large file async formatting
  -- ============================================================================
  {
    id = 10110,
    type = "async_integration",
    name = "Async format - large SQL uses async path",
    description = "Verify large SQL triggers async formatting (above threshold)",
    generate_input = {
      type = "repeat_select",
      count = 100, -- Generate 100 SELECT statements
    },
    expected = {
      formatted = true,
      async_path_used = true,
    },
    timeout_ms = 30000, -- Longer timeout for large file
  },
  {
    id = 10111,
    type = "async_integration",
    name = "Async format - progress callbacks called",
    description = "Verify progress callbacks are invoked during async formatting",
    skip = true, -- Progress callbacks not currently implemented in formatter
    skip_reason = "Progress callbacks feature not implemented",
    generate_input = {
      type = "repeat_select",
      count = 50,
    },
    expected = {
      progress_called = true,
      progress_increases = true,
    },
    timeout_ms = 20000,
  },

  -- ============================================================================
  -- Buffer formatting
  -- ============================================================================
  {
    id = 10120,
    type = "async_integration",
    name = "Async format buffer - applies changes",
    description = "Verify format_buffer_async applies formatted result to buffer",
    input_sql = "select * from employees",
    use_buffer = true,
    expected = {
      buffer_modified = true,
      buffer_contains = "SELECT",
      buffer_contains_2 = "FROM",
    },
    timeout_ms = 3000,
  },
  {
    id = 10121,
    type = "async_integration",
    name = "Async format buffer - completion callback",
    description = "Verify on_complete callback is called after buffer format",
    input_sql = "select * from employees",
    use_buffer = true,
    expected = {
      on_complete_called = true,
      success = true,
    },
    timeout_ms = 3000,
  },
  {
    id = 10122,
    type = "async_integration",
    name = "Async format range - partial buffer",
    description = "Verify format_range_async only affects specified lines",
    skip = true, -- Range formatting not implemented in test runner
    skip_reason = "Range formatting test infrastructure not implemented",
    input_lines = {
      "-- Comment line, should not change",
      "select * from employees",
      "-- Another comment",
    },
    format_range = { start = 2, end_line = 2 },
    expected = {
      line_1_unchanged = true,
      line_2_formatted = true,
      line_3_unchanged = true,
    },
    timeout_ms = 3000,
  },

  -- ============================================================================
  -- Error handling
  -- ============================================================================
  {
    id = 10130,
    type = "async_integration",
    name = "Async format - invalid SQL handling",
    description = "Verify async formatter handles invalid SQL gracefully",
    input_sql = "SELECT FROM WHERE",
    expected = {
      formatted = true, -- Best-effort formatting
      no_crash = true,
    },
    timeout_ms = 2000,
  },
  {
    id = 10131,
    type = "async_integration",
    name = "Async format - empty input",
    description = "Verify async formatter handles empty input",
    input_sql = "",
    expected = {
      callback_called = true,
      output_empty = true,
    },
    timeout_ms = 2000,
  },
  {
    id = 10132,
    type = "async_integration",
    name = "Async format - buffer deleted during format",
    description = "Verify async formatter handles buffer deletion gracefully",
    skip = true, -- Buffer deletion during async operation requires complex timing coordination
    skip_reason = "Buffer deletion timing test infrastructure not implemented",
    input_sql = "select * from employees",
    use_buffer = true,
    delete_buffer_during = true,
    expected = {
      on_complete_called = true,
      error_reported = true, -- Should report buffer invalid error
    },
    timeout_ms = 3000,
  },

  -- ============================================================================
  -- Concurrent formatting
  -- ============================================================================
  {
    id = 10140,
    type = "async_integration",
    name = "Async format - multiple concurrent formats",
    description = "Verify multiple async formats can run concurrently",
    skip = true, -- Concurrent formatting test requires parallel test execution infrastructure
    skip_reason = "Concurrent test execution infrastructure not implemented",
    concurrent_inputs = {
      "select * from employees",
      "select * from departments",
      "select * from orders",
    },
    expected = {
      all_completed = true,
      all_formatted = true,
    },
    timeout_ms = 5000,
  },

  -- ============================================================================
  -- Format-on-save async
  -- ============================================================================
  {
    id = 10150,
    type = "async_integration",
    name = "Async format on save - large file",
    description = "Verify format-on-save uses async for large files",
    generate_input = {
      type = "repeat_select",
      count = 30,
    },
    trigger_save = true,
    expected = {
      formatted_before_save = true,
      async_path_used = true,
    },
    timeout_ms = 15000,
  },
}
