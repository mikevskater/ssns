-- Integration tests: Async Completion Workflows
-- IDs: 10001-10050
-- Tests end-to-end async completion behaviors including:
-- - Completion with async database loading
-- - Completion cancellation on rapid input
-- - Async provider callbacks
-- - CancellationToken propagation

return {
  -- ============================================================================
  -- Basic async completion (tables)
  -- ============================================================================
  {
    id = 10001,
    type = "async_integration",
    name = "Async completion - table completion returns results",
    description = "Verify async table completion returns correct items",
    database = "vim_dadbod_test",
    query = "SELECT * FROM █",
    expected = {
      has_items = true,
      includes = { "Employees", "Departments", "Orders" },
      type = "table",
    },
    timeout_ms = 5000,
  },
  {
    id = 10002,
    type = "async_integration",
    name = "Async completion - schema-qualified table completion",
    description = "Verify async completion with schema prefix",
    database = "vim_dadbod_test",
    query = "SELECT * FROM dbo.█",
    expected = {
      has_items = true,
      includes = { "Employees", "Departments" },
      type = "table",
    },
    timeout_ms = 5000,
  },
  {
    id = 10003,
    type = "async_integration",
    name = "Async completion - cross-schema table completion",
    description = "Verify async completion for hr schema",
    database = "vim_dadbod_test",
    query = "SELECT * FROM hr.█",
    expected = {
      has_items = true,
      includes = { "Benefits" },
      type = "table",
    },
    timeout_ms = 5000,
  },

  -- ============================================================================
  -- Async column completion
  -- ============================================================================
  {
    id = 10010,
    type = "async_integration",
    name = "Async completion - column completion with alias",
    description = "Verify async column completion for aliased table",
    database = "vim_dadbod_test",
    query = "SELECT e.█ FROM Employees e",
    expected = {
      has_items = true,
      includes = { "EmployeeID", "FirstName", "LastName", "DepartmentID" },
      type = "column",
    },
    timeout_ms = 5000,
  },
  {
    id = 10011,
    type = "async_integration",
    name = "Async completion - column completion in WHERE clause",
    description = "Verify async column completion in WHERE clause",
    database = "vim_dadbod_test",
    query = "SELECT * FROM Employees WHERE █",
    expected = {
      has_items = true,
      includes = { "EmployeeID", "FirstName", "LastName" },
      type = "column",
    },
    timeout_ms = 5000,
  },
  {
    id = 10012,
    type = "async_integration",
    name = "Async completion - join column completion",
    description = "Verify async column completion in JOIN condition",
    database = "vim_dadbod_test",
    query = "SELECT * FROM Employees e JOIN Departments d ON e.█",
    expected = {
      has_items = true,
      includes = { "DepartmentID", "EmployeeID" },
      type = "column",
    },
    timeout_ms = 5000,
  },

  -- ============================================================================
  -- Async completion with multiple sources
  -- ============================================================================
  {
    id = 10020,
    type = "async_integration",
    name = "Async completion - unqualified column from multiple tables",
    description = "Verify async completion gathers columns from all tables in query",
    database = "vim_dadbod_test",
    query = "SELECT █ FROM Employees e, Departments d",
    expected = {
      has_items = true,
      includes = { "EmployeeID", "DepartmentID", "DepartmentName" },
      type = "column",
    },
    timeout_ms = 5000,
  },
  {
    id = 10021,
    type = "async_integration",
    name = "Async completion - callback timing",
    description = "Verify completion callback is always called",
    database = "vim_dadbod_test",
    query = "SELECT * FROM █",
    expected = {
      callback_called = true,
    },
    timeout_ms = 5000,
  },

  -- ============================================================================
  -- Cancellation scenarios
  -- ============================================================================
  {
    id = 10030,
    type = "async_integration",
    name = "Async completion - cancellation on new request",
    description = "Verify old completion is cancelled when new request arrives",
    database = "vim_dadbod_test",
    scenario = "rapid_input",
    inputs = {
      { query = "SELECT * FROM E█", delay_ms = 0 },
      { query = "SELECT * FROM Em█", delay_ms = 50 },
      { query = "SELECT * FROM Emp█", delay_ms = 50 },
    },
    expected = {
      final_result_only = true,
      includes = { "Employees" },
    },
    timeout_ms = 5000,
  },
  {
    id = 10031,
    type = "async_integration",
    name = "Async completion - immediate second request cancels first",
    description = "Verify immediate second request cancels the first (Source auto-cancellation)",
    database = "vim_dadbod_test",
    scenario = "rapid_input",
    inputs = {
      { query = "SELECT * FROM █", delay_ms = 0 },
      { query = "SELECT * FROM Emp█", delay_ms = 0 }, -- Immediate second request
    },
    expected = {
      final_result_only = true,
      includes = { "Employees" },
    },
    timeout_ms = 5000,
  },

  -- ============================================================================
  -- Database loading scenarios
  -- ============================================================================
  {
    id = 10040,
    type = "async_integration",
    name = "Async completion - cold database load",
    description = "Verify completion works when database is not pre-loaded",
    database = "vim_dadbod_test",
    clear_cache = true,
    query = "SELECT * FROM █",
    expected = {
      has_items = true,
      includes = { "Employees" },
    },
    timeout_ms = 10000, -- Longer timeout for cold load
  },
  {
    id = 10041,
    type = "async_integration",
    name = "Async completion - cached database",
    description = "Verify completion works with cached database (runs after 10040)",
    database = "vim_dadbod_test",
    query = "SELECT * FROM █",
    expected = {
      has_items = true,
      includes = { "Employees" },
    },
    timeout_ms = 5000,
  },

  -- ============================================================================
  -- Edge cases
  -- ============================================================================
  {
    id = 10050,
    type = "async_integration",
    name = "Async completion - empty query position",
    description = "Verify async completion handles empty prefix",
    database = "vim_dadbod_test",
    query = "█",
    expected = {
      callback_called = true, -- Should still call callback even with no results
    },
    timeout_ms = 5000,
  },
}
