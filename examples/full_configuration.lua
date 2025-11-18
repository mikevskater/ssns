-- ============================================================================
-- SSNS Full Configuration Example
-- ============================================================================
-- This file shows all available configuration options with their default values
-- and explanations. Copy sections you want to customize into your init.lua.
--
-- Minimal setup:
--   require('ssns').setup({
--     connections = {
--       my_db = "sqlserver://localhost/MyDatabase"
--     }
--   })
-- ============================================================================

require('ssns').setup({
  -- ============================================================================
  -- CONNECTIONS
  -- ============================================================================
  -- Define your database connections here
  -- Format: name = "connection_string"
  connections = {
    -- SQL Server examples
    dev_sqlserver = "sqlserver://localhost/DevDB",
    prod_sqlserver = "sqlserver://user:pass@server\\SQLEXPRESS/ProductionDB",

    -- PostgreSQL examples
    dev_postgres = "postgres://postgres:password@localhost:5432/devdb",
    prod_postgres = "postgresql://user:pass@remote-host:5432/proddb",

    -- MySQL examples
    dev_mysql = "mysql://root@localhost/myapp",
    prod_mysql = "mysql://user:pass@mysql-server:3306/production",

    -- SQLite examples
    local_sqlite = "sqlite://./data/app.db",
    test_sqlite = "sqlite://:memory:",  -- In-memory database
  },

  -- ============================================================================
  -- UI CONFIGURATION
  -- ============================================================================
  ui = {
    -- Window position: "left", "right", or "float"
    position = "left",

    -- Window width (sidebar mode)
    width = 40,

    -- Window height (float mode only)
    height = 30,

    -- Use SSMS-style UI (hierarchical tree)
    ssms_style = true,

    -- Show schema prefix in object names (e.g., [dbo].[TableName])
    show_schema_prefix = true,

    -- Auto-expand tree to this depth on load (nil = don't auto-expand)
    -- 1 = expand servers, 2 = expand databases, 3 = expand schemas, etc.
    auto_expand_depth = nil,

    -- Enable smart cursor positioning on j/k movement
    -- When true, cursor snaps to start of object names
    smart_cursor_positioning = true,

    -- Show help text at top of tree buffer
    show_help = true,

    -- Divider between multiple result sets
    -- Format supports:
    --   - Repeat patterns: "20#" = 20 hash symbols
    --   - Raw strings: "---- Result Set ----"
    --   - Variables: %row_count%, %col_count%, %run_time%, %result_set_num%, etc.
    --   - Auto-width: %fit% = matches longest line width
    --   - Multi-line: use \n for newlines
    -- Examples:
    --   ""                                              (empty - just blank line)
    --   "20#"                                           (20 hash symbols)
    --   "5-(%row_count% rows)5-"                        (-----(11 rows)-----)
    --   "%fit%=\n-- Result Set %result_set_num% --\n%fit%="
    result_set_divider = "",

    -- Show divider before first result set and for single result sets
    -- If false, divider only shows between multiple result sets
    show_result_set_info = false,

    -- Icons for different object types
    -- Uses Nerd Fonts - set to "" if you don't have Nerd Fonts installed
    icons = {
      server = "",      -- Server icon
      database = "",    -- Database icon
      schema = "",      -- Schema/folder icon
      table = "",       -- Table icon
      view = "",        -- View icon
      procedure = "",   -- Procedure icon
      ["function"] = "", -- Function icon (note: 'function' is keyword, use brackets)
      column = "",      -- Column icon
      index = "",       -- Index icon
      key = "",         -- Key/constraint icon
      action = "",      -- Action icon
      sequence = "",    -- Sequence icon (PostgreSQL)
      synonym = "",     -- Synonym icon (SQL Server)
    },
  },

  -- ============================================================================
  -- CACHE CONFIGURATION
  -- ============================================================================
  cache = {
    -- Time to live in seconds for cached query results
    ttl = 300,  -- 5 minutes

    -- Enable query result caching
    enabled = true,
  },

  -- ============================================================================
  -- QUERY CONFIGURATION
  -- ============================================================================
  query = {
    -- Default LIMIT for SELECT queries
    -- Applied when using table actions like "SELECT"
    -- 0 = no limit (return all rows - use with caution!)
    default_limit = 100,

    -- Query timeout in milliseconds
    -- 0 = no timeout (query runs until complete)
    timeout = 30000,  -- 30 seconds

    -- Auto-execute query when opening action
    -- If true, queries execute immediately when you select an action
    -- If false, query is inserted into buffer for manual execution
    auto_execute_on_open = false,
  },

  -- ============================================================================
  -- KEYMAPS CONFIGURATION
  -- ============================================================================
  -- Keymaps used in SSNS tree and query buffers
  keymaps = {
    -- Tree buffer keymaps
    toggle = "<CR>",              -- Toggle expand/collapse or execute action
    close = "q",                  -- Close SSNS window
    refresh = "r",                -- Refresh current node
    refresh_all = "R",            -- Refresh all servers
    help = "?",                   -- Show help
    toggle_connection = "S",      -- Toggle server connection (connect/disconnect)

    -- Query buffer keymaps
    execute = "<Leader>r",        -- Execute query (normal mode)
    execute_selection = "<Leader>r",  -- Execute visual selection (visual mode)
    save_query = "<Leader>s",     -- Save current query to file
  },

  -- ============================================================================
  -- TABLE HELPERS CONFIGURATION
  -- ============================================================================
  -- Database-specific SQL templates for table actions
  -- Variables:
  --   {table}     - Full qualified table name
  --   {columns}   - Comma-separated list of columns
  --   {values}    - Comma-separated placeholders for values
  --   {column}    - Single column name placeholder
  --   {value}     - Single value placeholder
  --   {condition} - WHERE condition placeholder
  table_helpers = {
    -- SQL Server templates
    sqlserver = {
      ["SELECT Top 100"] = "SELECT TOP 100 * FROM {table};",
      ["SELECT Top 1000"] = "SELECT TOP 1000 * FROM {table};",
      ["Count"] = "SELECT COUNT(*) AS row_count FROM {table};",
      ["Describe"] = "EXEC sp_help '{table}';",
      ["INSERT Template"] = "INSERT INTO {table} ({columns})\nVALUES ({values});",
      ["UPDATE Template"] = "UPDATE {table}\nSET {column} = {value}\nWHERE {condition};",
      ["DELETE Template"] = "DELETE FROM {table}\nWHERE {condition};",
    },

    -- PostgreSQL templates
    postgres = {
      ["SELECT Limit 100"] = "SELECT * FROM {table} LIMIT 100;",
      ["SELECT Limit 1000"] = "SELECT * FROM {table} LIMIT 1000;",
      ["Count"] = "SELECT COUNT(*) AS row_count FROM {table};",
      ["Describe"] = "\\d+ {table}",  -- psql meta-command
      ["INSERT Template"] = "INSERT INTO {table} ({columns})\nVALUES ({values})\nRETURNING *;",
      ["UPDATE Template"] = "UPDATE {table}\nSET {column} = {value}\nWHERE {condition}\nRETURNING *;",
      ["DELETE Template"] = "DELETE FROM {table}\nWHERE {condition};",
    },

    -- MySQL templates
    mysql = {
      ["SELECT Limit 100"] = "SELECT * FROM {table} LIMIT 100;",
      ["SELECT Limit 1000"] = "SELECT * FROM {table} LIMIT 1000;",
      ["Count"] = "SELECT COUNT(*) AS row_count FROM {table};",
      ["Describe"] = "DESCRIBE {table};",
      ["INSERT Template"] = "INSERT INTO {table} ({columns})\nVALUES ({values});",
      ["UPDATE Template"] = "UPDATE {table}\nSET {column} = {value}\nWHERE {condition};",
      ["DELETE Template"] = "DELETE FROM {table}\nWHERE {condition};",
    },

    -- SQLite templates
    sqlite = {
      ["SELECT Limit 100"] = "SELECT * FROM {table} LIMIT 100;",
      ["SELECT Limit 1000"] = "SELECT * FROM {table} LIMIT 1000;",
      ["Count"] = "SELECT COUNT(*) AS row_count FROM {table};",
      ["Describe"] = "PRAGMA table_info({table});",
      ["INSERT Template"] = "INSERT INTO {table} ({columns})\nVALUES ({values});",
      ["UPDATE Template"] = "UPDATE {table}\nSET {column} = {value}\nWHERE {condition};",
      ["DELETE Template"] = "DELETE FROM {table}\nWHERE {condition};",
    },
  },

  -- ============================================================================
  -- PERFORMANCE CONFIGURATION
  -- ============================================================================
  performance = {
    -- Enable lazy loading of tree nodes
    -- When true, child nodes only load when expanded
    lazy_load = true,

    -- Number of items to load per page
    -- 0 = load all items at once
    -- Useful for databases with thousands of tables
    page_size = 0,

    -- Use async operations where possible
    -- Prevents UI blocking during database operations
    async = true,
  },
})

-- ============================================================================
-- ADDITIONAL SETUP
-- ============================================================================

-- You can also add connections dynamically after setup:
-- require('ssns.config').add_connection('new_db', 'sqlserver://localhost/NewDB')

-- Or remove connections:
-- require('ssns.config').remove_connection('dev_sqlserver')

-- Get current configuration:
-- local config = require('ssns.config').get()
-- print(vim.inspect(config))

-- ============================================================================
-- KEYMAP EXAMPLES
-- ============================================================================

-- Global keymap to toggle SSNS
vim.keymap.set('n', '<Leader>db', ':SSNSToggle<CR>', { desc = 'Toggle SSNS', silent = true })

-- Additional keymaps
vim.keymap.set('n', '<Leader>do', ':SSNSOpen<CR>', { desc = 'Open SSNS', silent = true })
vim.keymap.set('n', '<Leader>dc', ':SSNSClose<CR>', { desc = 'Close SSNS', silent = true })
vim.keymap.set('n', '<Leader>dr', ':SSNSRefresh<CR>', { desc = 'Refresh SSNS', silent = true })

-- ============================================================================
-- TIPS & TRICKS
-- ============================================================================

-- 1. Connection String Formats:
--    SQL Server:   sqlserver://[user:pass@]server[\instance][/database]
--    PostgreSQL:   postgres://[user:pass@]host[:port]/database
--    MySQL:        mysql://[user:pass@]host[:port]/database
--    SQLite:       sqlite://path/to/file.db or sqlite://:memory:

-- 2. Multi-Result Set Dividers:
--    For nice dividers between result sets, try:
--    result_set_divider = "%fit%=\n=== Result Set %result_set_num% of %total_result_sets% (%row_count% rows, %run_time%) ===\n%fit%="

-- 3. Custom Table Helpers:
--    Add your own templates for frequently-used queries:
--    table_helpers.sqlserver["Find Duplicates"] = "SELECT {column}, COUNT(*) FROM {table} GROUP BY {column} HAVING COUNT(*) > 1;"

-- 4. Performance Tuning:
--    For large databases (1000+ tables), consider:
--    - performance.page_size = 100 (load 100 items at a time)
--    - cache.ttl = 600 (cache for 10 minutes)
--    - ui.auto_expand_depth = 1 (only expand servers by default)

-- ============================================================================
-- END OF CONFIGURATION
-- ============================================================================
