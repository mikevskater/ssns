-- Test file: completion_providers.lua
-- IDs: 9400-9450
-- Tests: Async completion provider methods
-- Tests TablesProvider, ColumnsProvider, and other async providers

return {
  -- ============================================================================
  -- TablesProvider.get_completions_async tests
  -- ============================================================================
  {
    id = 9401,
    type = "async",
    name = "TablesProvider async - returns tables from loaded database",
    module = "ssns.completion.providers",
    method = "tables_async",
    setup = {
      mock_database = true,
    },
    expected = {
      has_items = true,
      includes_table = "Employees",
    },
  },
  {
    id = 9402,
    type = "async",
    name = "TablesProvider async - returns views from loaded database",
    module = "ssns.completion.providers",
    method = "tables_async",
    setup = {
      mock_database = true,
    },
    expected = {
      has_items = true,
      includes_table = "vw_ActiveEmployees",
    },
  },
  {
    id = 9403,
    type = "async",
    name = "TablesProvider async - empty on nil connection",
    module = "ssns.completion.providers",
    method = "tables_async_nil_connection",
    expected = {
      empty_result = true,
    },
  },
  {
    id = 9404,
    type = "async",
    name = "TablesProvider async - respects cancellation token",
    module = "ssns.completion.providers",
    method = "tables_async_cancelled",
    setup = {
      mock_database = true,
      pre_cancel = true,
    },
    expected = {
      callback_not_called_with_items = true,
    },
  },

  -- ============================================================================
  -- ColumnsProvider.get_completions_async tests
  -- ============================================================================
  {
    id = 9410,
    type = "async",
    name = "ColumnsProvider async - returns columns for qualified table",
    module = "ssns.completion.providers",
    method = "columns_async_qualified",
    setup = {
      mock_database = true,
      table_ref = "Employees",
    },
    expected = {
      has_items = true,
      includes_column = "EmployeeID",
    },
  },
  {
    id = 9411,
    type = "async",
    name = "ColumnsProvider async - empty for non-existent table",
    module = "ssns.completion.providers",
    method = "columns_async_nonexistent",
    setup = {
      mock_database = true,
      table_ref = "NonExistentTable",
    },
    expected = {
      empty_result = true,
    },
  },
  {
    id = 9412,
    type = "async",
    name = "ColumnsProvider async - respects cancellation token",
    module = "ssns.completion.providers",
    method = "columns_async_cancelled",
    setup = {
      mock_database = true,
      pre_cancel = true,
    },
    expected = {
      callback_not_called_with_items = true,
    },
  },

  -- ============================================================================
  -- SchemasProvider.get_completions_async tests
  -- ============================================================================
  {
    id = 9420,
    type = "async",
    name = "SchemasProvider async - returns schemas",
    module = "ssns.completion.providers",
    method = "schemas_async",
    setup = {
      mock_database = true,
    },
    expected = {
      has_items = true,
      includes_schema = "dbo",
    },
  },

  -- ============================================================================
  -- DatabasesProvider.get_completions_async tests
  -- ============================================================================
  {
    id = 9425,
    type = "async",
    name = "DatabasesProvider async - returns databases",
    module = "ssns.completion.providers",
    method = "databases_async",
    setup = {
      mock_server = true,
    },
    expected = {
      has_items = true,
      includes_database = "vim_dadbod_test",
    },
  },

  -- ============================================================================
  -- Async timeout and callback behavior
  -- ============================================================================
  {
    id = 9430,
    type = "async",
    name = "Async providers - callback is always called",
    module = "ssns.completion.providers",
    method = "callback_always_called",
    setup = {
      mock_database = true,
    },
    expected = {
      callback_called = true,
    },
  },
  {
    id = 9431,
    type = "async",
    name = "Async providers - callback called via vim.schedule",
    module = "ssns.completion.providers",
    method = "callback_scheduled",
    setup = {
      mock_database = true,
    },
    expected = {
      callback_scheduled = true,
    },
  },
}
