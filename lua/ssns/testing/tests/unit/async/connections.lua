-- Test file: connections.lua
-- IDs: 9100-9150
-- Tests: Async connection management operations
-- These tests verify the Connections module's async load/save operations

return {
  -- ============================================================================
  -- Load connections async tests
  -- ============================================================================
  {
    id = 9101,
    type = "async",
    name = "Load connections from empty file returns empty array",
    module = "ssns.connections",
    method = "load_async",
    setup = {
      connections_file = true,
      connections = {},
    },
    expected = {
      success = true,
      connections_count = 0,
    },
  },
  {
    id = 9102,
    type = "async",
    name = "Load connections with one connection",
    module = "ssns.connections",
    method = "load_async",
    setup = {
      connections_file = true,
      connections = {
        {
          name = "Test Server",
          type = "sqlserver",
          server = { host = "localhost" },
          auth = { type = "windows" },
          favorite = false,
          auto_connect = false,
        },
      },
    },
    expected = {
      success = true,
      connections_count = 1,
      has_connection = "Test Server",
    },
  },
  {
    id = 9103,
    type = "async",
    name = "Load connections with multiple connections",
    module = "ssns.connections",
    method = "load_async",
    setup = {
      connections_file = true,
      connections = {
        {
          name = "Server 1",
          type = "sqlserver",
          server = { host = "host1" },
          auth = { type = "windows" },
          favorite = true,
          auto_connect = false,
        },
        {
          name = "Server 2",
          type = "postgres",
          server = { host = "host2", port = 5432 },
          auth = { type = "sql", username = "user" },
          favorite = false,
          auto_connect = true,
        },
      },
    },
    expected = {
      success = true,
      connections_count = 2,
      has_connection = "Server 1",
    },
  },
  {
    id = 9104,
    type = "async",
    name = "Load connections from non-existent file returns empty array",
    module = "ssns.connections",
    method = "load_async",
    setup = {
      no_connections_file = true,
    },
    expected = {
      success = true,
      connections_count = 0,
    },
  },

  -- ============================================================================
  -- Save connections async tests
  -- ============================================================================
  {
    id = 9110,
    type = "async",
    name = "Save empty connections array",
    module = "ssns.connections",
    method = "save_async",
    input = {
      connections = {},
    },
    expected = {
      success = true,
      verify_file_exists = true,
    },
  },
  {
    id = 9111,
    type = "async",
    name = "Save single connection",
    module = "ssns.connections",
    method = "save_async",
    input = {
      connections = {
        {
          name = "New Server",
          type = "mysql",
          server = { host = "mysql.example.com", port = 3306 },
          auth = { type = "sql", username = "root" },
          favorite = true,
          auto_connect = false,
        },
      },
    },
    expected = {
      success = true,
      verify_file_exists = true,
      verify_has_connection = "New Server",
    },
  },

  -- ============================================================================
  -- Add connection async tests
  -- ============================================================================
  {
    id = 9120,
    type = "async",
    name = "Add connection to empty file",
    module = "ssns.connections",
    method = "add_async",
    setup = {
      connections_file = true,
      connections = {},
    },
    input = {
      connection = {
        name = "Added Server",
        type = "sqlserver",
        server = { host = "added.example.com" },
        auth = { type = "windows" },
      },
    },
    expected = {
      success = true,
      verify_has_connection = "Added Server",
    },
  },
  {
    id = 9121,
    type = "async",
    name = "Add connection fails with duplicate name",
    module = "ssns.connections",
    method = "add_async",
    setup = {
      connections_file = true,
      connections = {
        {
          name = "Existing",
          type = "sqlserver",
          server = { host = "host" },
          auth = { type = "windows" },
          favorite = false,
          auto_connect = false,
        },
      },
    },
    input = {
      connection = {
        name = "Existing", -- Duplicate name
        type = "postgres",
        server = { host = "other" },
        auth = { type = "sql", username = "user" },
      },
    },
    expected = {
      success = false,
      has_error = true,
    },
  },
  {
    id = 9122,
    type = "async",
    name = "Add connection fails with invalid data",
    module = "ssns.connections",
    method = "add_async",
    setup = {
      connections_file = true,
      connections = {},
    },
    input = {
      connection = {
        -- Missing required fields
        name = "",
        type = "sqlserver",
      },
    },
    expected = {
      success = false,
      has_error = true,
    },
  },

  -- ============================================================================
  -- Remove connection async tests
  -- ============================================================================
  {
    id = 9130,
    type = "async",
    name = "Remove existing connection",
    module = "ssns.connections",
    method = "remove_async",
    setup = {
      connections_file = true,
      connections = {
        {
          name = "ToRemove",
          type = "sqlserver",
          server = { host = "host" },
          auth = { type = "windows" },
          favorite = false,
          auto_connect = false,
        },
        {
          name = "ToKeep",
          type = "postgres",
          server = { host = "other" },
          auth = { type = "sql", username = "u" },
          favorite = false,
          auto_connect = false,
        },
      },
    },
    input = {
      name = "ToRemove",
    },
    expected = {
      success = true,
      verify_no_connection = "ToRemove",
      verify_has_connection = "ToKeep",
    },
  },
  {
    id = 9131,
    type = "async",
    name = "Remove non-existent connection fails",
    module = "ssns.connections",
    method = "remove_async",
    setup = {
      connections_file = true,
      connections = {},
    },
    input = {
      name = "NonExistent",
    },
    expected = {
      success = false,
      has_error = true,
    },
  },

  -- ============================================================================
  -- Update connection async tests
  -- ============================================================================
  {
    id = 9140,
    type = "async",
    name = "Update existing connection",
    module = "ssns.connections",
    method = "update_async",
    setup = {
      connections_file = true,
      connections = {
        {
          name = "ToUpdate",
          type = "sqlserver",
          server = { host = "old-host" },
          auth = { type = "windows" },
          favorite = false,
          auto_connect = false,
        },
      },
    },
    input = {
      name = "ToUpdate",
      connection = {
        name = "ToUpdate",
        type = "sqlserver",
        server = { host = "new-host" },
        auth = { type = "windows" },
        favorite = true,
        auto_connect = false,
      },
    },
    expected = {
      success = true,
      verify_connection_host = { name = "ToUpdate", host = "new-host" },
    },
  },
  {
    id = 9141,
    type = "async",
    name = "Update non-existent connection fails",
    module = "ssns.connections",
    method = "update_async",
    setup = {
      connections_file = true,
      connections = {},
    },
    input = {
      name = "NonExistent",
      connection = {
        name = "NonExistent",
        type = "sqlserver",
        server = { host = "host" },
        auth = { type = "windows" },
      },
    },
    expected = {
      success = false,
      has_error = true,
    },
  },

  -- ============================================================================
  -- Find connection async tests
  -- ============================================================================
  {
    id = 9145,
    type = "async",
    name = "Find existing connection",
    module = "ssns.connections",
    method = "find_async",
    setup = {
      connections_file = true,
      connections = {
        {
          name = "FindMe",
          type = "sqlite",
          server = { host = "db.sqlite" },
          auth = { type = "none" },
          favorite = true,
          auto_connect = false,
        },
      },
    },
    input = {
      name = "FindMe",
    },
    expected = {
      success = true,
      found = true,
      connection_name = "FindMe",
    },
  },
  {
    id = 9146,
    type = "async",
    name = "Find non-existent connection returns nil",
    module = "ssns.connections",
    method = "find_async",
    setup = {
      connections_file = true,
      connections = {},
    },
    input = {
      name = "Missing",
    },
    expected = {
      success = true,
      found = false,
    },
  },

  -- ============================================================================
  -- Toggle favorite async tests
  -- ============================================================================
  {
    id = 9150,
    type = "async",
    name = "Toggle favorite from false to true",
    module = "ssns.connections",
    method = "toggle_favorite_async",
    setup = {
      connections_file = true,
      connections = {
        {
          name = "ToggleMe",
          type = "sqlserver",
          server = { host = "host" },
          auth = { type = "windows" },
          favorite = false,
          auto_connect = false,
        },
      },
    },
    input = {
      name = "ToggleMe",
    },
    expected = {
      success = true,
      new_state = true,
    },
  },
}
