-- Integration tests: Async Export Workflows
-- IDs: 10201-10250
-- Tests end-to-end async export behaviors including:
-- - CSV export with async file I/O
-- - Progress callbacks during large exports
-- - Export cancellation
-- - Multi-result set export

return {
  -- ============================================================================
  -- Basic async CSV export
  -- ============================================================================
  {
    id = 10201,
    type = "async_integration",
    name = "Async export - small result set",
    description = "Verify async CSV export of small result set",
    mock_results = {
      columns = { "EmployeeID", "FirstName", "LastName" },
      rows = {
        { 1, "John", "Doe" },
        { 2, "Jane", "Smith" },
        { 3, "Bob", "Johnson" },
      },
    },
    expected = {
      file_created = true,
      has_header = true,
      row_count = 3,
      contains = "John,Doe",
    },
    timeout_ms = 3000,
  },
  {
    id = 10202,
    type = "async_integration",
    name = "Async export - column headers",
    description = "Verify CSV export includes correct column headers",
    mock_results = {
      columns = { "ID", "Name", "Value" },
      rows = {
        { 1, "Test", 100 },
      },
    },
    expected = {
      file_created = true,
      first_line = "ID,Name,Value",
    },
    timeout_ms = 3000,
  },
  {
    id = 10203,
    type = "async_integration",
    name = "Async export - special characters escaped",
    description = "Verify CSV export properly escapes special characters",
    mock_results = {
      columns = { "Name", "Description" },
      rows = {
        { "Test", 'Contains "quotes" and, commas' },
        { "Another", "Has\nnewlines" },
      },
    },
    expected = {
      file_created = true,
      properly_escaped = true,
    },
    timeout_ms = 3000,
  },

  -- ============================================================================
  -- Large result set async export
  -- ============================================================================
  {
    id = 10210,
    type = "async_integration",
    name = "Async export - large result set",
    description = "Verify async export of large result set with progress",
    generate_results = {
      columns = { "ID", "Value" },
      row_count = 10000,
    },
    expected = {
      file_created = true,
      row_count = 10000,
      async_path_used = true,
    },
    timeout_ms = 30000,
  },
  {
    id = 10211,
    type = "async_integration",
    name = "Async export - progress callbacks",
    description = "Verify progress callbacks during large export",
    generate_results = {
      columns = { "ID", "Value" },
      row_count = 5000,
    },
    expected = {
      progress_called = true,
      progress_increases = true,
    },
    timeout_ms = 20000,
  },
  {
    id = 10212,
    type = "async_integration",
    name = "Async export - completion callback timing",
    description = "Verify on_complete is called after file is written",
    generate_results = {
      columns = { "ID" },
      row_count = 1000,
    },
    expected = {
      on_complete_called = true,
      file_exists_at_complete = true,
    },
    timeout_ms = 10000,
  },

  -- ============================================================================
  -- Multi-result set export
  -- ============================================================================
  {
    id = 10220,
    type = "async_integration",
    name = "Async export - all results to separate files",
    description = "Verify export_all_results_to_csv_async creates multiple files",
    mock_multi_results = {
      {
        columns = { "EmployeeID", "Name" },
        rows = { { 1, "John" }, { 2, "Jane" } },
      },
      {
        columns = { "DepartmentID", "Name" },
        rows = { { 1, "HR" }, { 2, "IT" } },
      },
    },
    expected = {
      files_created = 2,
      all_have_headers = true,
    },
    timeout_ms = 5000,
  },
  {
    id = 10221,
    type = "async_integration",
    name = "Async export - sequential file writes",
    description = "Verify multiple result sets are written sequentially",
    mock_multi_results = {
      {
        columns = { "A" },
        rows = { { 1 } },
      },
      {
        columns = { "B" },
        rows = { { 2 } },
      },
      {
        columns = { "C" },
        rows = { { 3 } },
      },
    },
    expected = {
      all_completed = true,
      no_file_conflicts = true,
    },
    timeout_ms = 5000,
  },

  -- ============================================================================
  -- Error handling
  -- ============================================================================
  {
    id = 10230,
    type = "async_integration",
    name = "Async export - empty result set",
    description = "Verify async export handles empty result set",
    mock_results = {
      columns = { "ID", "Name" },
      rows = {},
    },
    expected = {
      file_created = true,
      has_header = true,
      row_count = 0,
    },
    timeout_ms = 3000,
  },
  {
    id = 10231,
    type = "async_integration",
    name = "Async export - invalid path handling",
    description = "Verify async export handles invalid file path",
    mock_results = {
      columns = { "ID" },
      rows = { { 1 } },
    },
    export_path = "/nonexistent/directory/file.csv",
    expected = {
      error_reported = true,
      on_error_called = true,
    },
    timeout_ms = 3000,
  },
  {
    id = 10232,
    type = "async_integration",
    name = "Async export - null values",
    description = "Verify async export handles NULL values",
    mock_results = {
      columns = { "ID", "Name", "Value" },
      rows = {
        { 1, nil, 100 },
        { 2, "Test", nil },
        { nil, "Null ID", 200 },
      },
    },
    expected = {
      file_created = true,
      nulls_handled = true, -- NULLs should become empty strings
    },
    timeout_ms = 3000,
  },

  -- ============================================================================
  -- File I/O async behavior
  -- ============================================================================
  {
    id = 10240,
    type = "async_integration",
    name = "Async export - file write uses libuv",
    description = "Verify export uses async file I/O (not blocking)",
    generate_results = {
      columns = { "ID", "Data" },
      row_count = 500,
      data_size = 1000, -- Large data per row
    },
    expected = {
      non_blocking = true, -- UI should remain responsive
      file_created = true,
    },
    timeout_ms = 15000,
  },
  {
    id = 10241,
    type = "async_integration",
    name = "Async export - chunked writing",
    description = "Verify large exports use chunked file writing",
    generate_results = {
      columns = { "ID" },
      row_count = 50000, -- Very large result set
    },
    expected = {
      chunked_write_used = true,
      file_created = true,
    },
    timeout_ms = 60000,
  },

  -- ============================================================================
  -- Concurrent exports
  -- ============================================================================
  {
    id = 10250,
    type = "async_integration",
    name = "Async export - multiple concurrent exports",
    description = "Verify multiple exports can run concurrently",
    skip = true, -- Concurrent export test requires parallel test execution infrastructure
    skip_reason = "Concurrent test execution infrastructure not implemented",
    concurrent_exports = {
      {
        mock_results = { columns = { "A" }, rows = { { 1 } } },
        filename = "export1.csv",
      },
      {
        mock_results = { columns = { "B" }, rows = { { 2 } } },
        filename = "export2.csv",
      },
      {
        mock_results = { columns = { "C" }, rows = { { 3 } } },
        filename = "export3.csv",
      },
    },
    expected = {
      all_files_created = true,
      no_data_corruption = true,
    },
    timeout_ms = 10000,
  },
}
