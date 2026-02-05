-- Integration tests: Async RPC Workflows
-- IDs: 10301-10350
-- Tests end-to-end async RPC behaviors including:
-- - True RPC async server connection
-- - True RPC async database loading
-- - Non-blocking UI during RPC operations
-- - Cancellation of RPC operations

return {
  -- ============================================================================
  -- Server connection async
  -- ============================================================================
  {
    id = 10301,
    type = "async_integration",
    name = "RPC async - server connect",
    description = "Verify server connect_async is truly non-blocking",
    operation = "server_connect",
    expected = {
      non_blocking = true,
      callback_called = true,
      connected = true,
    },
    timeout_ms = 10000,
  },
  {
    id = 10302,
    type = "async_integration",
    name = "RPC async - server connect with invalid credentials",
    description = "Verify server connect_async handles connection failure",
    skip = true, -- Connection failure handling varies by driver and may timeout
    skip_reason = "Invalid connection test requires driver-specific error handling",
    operation = "server_connect",
    use_invalid_connection = true,
    expected = {
      callback_called = true,
      error_reported = true,
      non_blocking = true,
    },
    timeout_ms = 15000,
  },
  {
    id = 10303,
    type = "async_integration",
    name = "RPC async - server load databases",
    description = "Verify server load_async returns database list",
    operation = "server_load",
    expected = {
      non_blocking = true,
      callback_called = true,
      has_databases = true,
      includes_database = "vim_dadbod_test",
    },
    timeout_ms = 10000,
  },

  -- ============================================================================
  -- Database loading async
  -- ============================================================================
  {
    id = 10310,
    type = "async_integration",
    name = "RPC async - database load schemas",
    description = "Verify database load_async returns schemas",
    operation = "database_load",
    database = "vim_dadbod_test",
    expected = {
      non_blocking = true,
      callback_called = true,
      has_schemas = true,
      includes_schema = "dbo",
    },
    timeout_ms = 10000,
  },
  {
    id = 10311,
    type = "async_integration",
    name = "RPC async - database load tables",
    description = "Verify database load includes tables in schemas",
    operation = "database_load",
    database = "vim_dadbod_test",
    expected = {
      has_tables = true,
      includes_table = "Employees",
    },
    timeout_ms = 10000,
  },
  {
    id = 10312,
    type = "async_integration",
    name = "RPC async - database load views",
    description = "Verify database load includes views",
    operation = "database_load",
    database = "vim_dadbod_test",
    expected = {
      has_views = true,
      includes_view = "vw_ActiveEmployees",
    },
    timeout_ms = 10000,
  },

  -- ============================================================================
  -- Combined connect and load
  -- ============================================================================
  {
    id = 10320,
    type = "async_integration",
    name = "RPC async - connect and load combined",
    description = "Verify connect_and_load_async chains correctly",
    skip = true, -- Combined operation requires connect_and_load_async implementation
    skip_reason = "connect_and_load_async method not yet implemented on Server class",
    operation = "connect_and_load",
    expected = {
      non_blocking = true,
      callback_called = true,
      connected = true,
      has_databases = true,
    },
    timeout_ms = 15000,
  },
  {
    id = 10321,
    type = "async_integration",
    name = "RPC async - connect and load with progress",
    description = "Verify connect_and_load reports progress stages",
    operation = "connect_and_load",
    expected = {
      progress_stages = { "connecting", "loading" },
    },
    timeout_ms = 15000,
  },

  -- ============================================================================
  -- Column metadata async
  -- ============================================================================
  {
    id = 10330,
    type = "async_integration",
    name = "RPC async - get columns for table",
    description = "Verify column metadata fetch is non-blocking",
    operation = "get_columns",
    database = "vim_dadbod_test",
    table = "Employees",
    expected = {
      non_blocking = true,
      callback_called = true,
      has_columns = true,
      includes_column = "EmployeeID",
    },
    timeout_ms = 10000,
  },
  {
    id = 10331,
    type = "async_integration",
    name = "RPC async - get columns includes types",
    description = "Verify column metadata includes data types",
    operation = "get_columns",
    database = "vim_dadbod_test",
    table = "Employees",
    expected = {
      columns_have_types = true,
    },
    timeout_ms = 10000,
  },
  {
    id = 10332,
    type = "async_integration",
    name = "RPC async - get columns for non-existent table",
    description = "Verify column fetch handles missing table",
    operation = "get_columns",
    database = "vim_dadbod_test",
    table = "NonExistentTable",
    expected = {
      callback_called = true,
      empty_result = true,
    },
    timeout_ms = 10000,
  },

  -- ============================================================================
  -- Non-blocking verification
  -- ============================================================================
  {
    id = 10340,
    type = "async_integration",
    name = "RPC async - UI remains responsive during load",
    description = "Verify UI thread is not blocked during RPC",
    operation = "server_load",
    verify_responsiveness = true,
    expected = {
      ui_responsive = true,
      timer_fired = true, -- A timer should fire during async operation
    },
    timeout_ms = 15000,
  },
  {
    id = 10341,
    type = "async_integration",
    name = "RPC async - multiple concurrent RPC calls",
    description = "Verify multiple RPC calls can run concurrently",
    skip = true, -- Concurrent RPC test requires parallel test execution infrastructure
    skip_reason = "Concurrent RPC test infrastructure not implemented",
    operation = "concurrent_rpc",
    concurrent_operations = {
      { type = "database_load", database = "vim_dadbod_test" },
      { type = "get_columns", table = "Employees" },
      { type = "get_columns", table = "Departments" },
    },
    expected = {
      all_completed = true,
      concurrent_execution = true,
    },
    timeout_ms = 20000,
  },

  -- ============================================================================
  -- Cancellation
  -- ============================================================================
  {
    id = 10345,
    type = "async_integration",
    name = "RPC async - cancellation token respected",
    description = "Verify RPC async operations check cancellation",
    operation = "database_load",
    database = "vim_dadbod_test",
    pre_cancel = true,
    expected = {
      callback_not_called = true,
      operation_cancelled = true,
    },
    timeout_ms = 5000,
  },
  {
    id = 10346,
    type = "async_integration",
    name = "RPC async - mid-operation cancellation",
    description = "Verify cancellation during RPC prevents callback",
    operation = "connect_and_load",
    cancel_after_ms = 100,
    expected = {
      partial_or_no_result = true,
    },
    timeout_ms = 10000,
  },

  -- ============================================================================
  -- Tree integration
  -- ============================================================================
  {
    id = 10350,
    type = "async_integration",
    name = "RPC async - tree node expansion",
    description = "Verify tree node expansion uses true async RPC",
    skip = true, -- Tree integration test requires UI tree component setup
    skip_reason = "Tree expansion test infrastructure not implemented",
    operation = "tree_expand",
    node_type = "server",
    expected = {
      non_blocking = true,
      node_expanded = true,
      children_loaded = true,
    },
    timeout_ms = 15000,
  },
}
