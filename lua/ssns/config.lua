---@class SsnsConfig
---@field connections table<string, string> Map of connection names to connection strings
---@field ui UiConfig UI configuration
---@field cache CacheConfig Cache configuration
---@field query QueryConfig Query execution configuration
---@field keymaps KeymapsConfig Keymap configuration
---@field table_helpers TableHelpersConfig Table helper templates per database type
---@field performance PerformanceConfig Performance tuning options

---@class UiConfig
---@field position string Window position: "left", "right", "float"
---@field width number Window width
---@field height number? Window height (for float)
---@field ssms_style boolean Use SSMS-style UI
---@field show_schema_prefix boolean Show schema prefix in object names
---@field auto_expand_depth number? Auto-expand tree to this depth on load
---@field smart_cursor_positioning boolean Enable smart cursor positioning on j/k movement (default: true)
---@field result_set_divider string? Format for divider between multiple result sets (default: "")
---@field show_result_set_info boolean Show divider/info before first result set and single result sets (default: false)
---@field show_help boolean Show help text at top of tree buffer (default: true)
---@field icons IconsConfig Icon configuration

---@class IconsConfig
---@field server string Server icon
---@field database string Database icon
---@field schema string Schema/folder icon
---@field table string Table icon
---@field view string View icon
---@field procedure string Procedure icon
---@field function string Function icon
---@field column string Column icon
---@field index string Index icon
---@field key string Key/constraint icon
---@field action string Action icon
---@field sequence string Sequence icon
---@field synonym string Synonym icon
---@field connected string Connected status icon
---@field disconnected string Disconnected status icon
---@field connecting string Connecting/loading status icon
---@field error string Error status icon
---@field expanded string Expanded tree node icon
---@field collapsed string Collapsed tree node icon

---@class CacheConfig
---@field ttl number Time to live in seconds for cached data
---@field enabled boolean Enable query result caching (default: true)

---@class QueryConfig
---@field default_limit number Default LIMIT for SELECT queries (0 = no limit)
---@field timeout number Query timeout in milliseconds (0 = no timeout)
---@field auto_execute_on_open boolean Auto-execute query when opening action (default: false)

---@class KeymapsConfig
---@field toggle string Toggle SSNS tree window
---@field execute string Execute query in buffer
---@field execute_selection string Execute visual selection
---@field save_query string Save current query to file
---@field close string Close SSNS window
---@field refresh string Refresh current node
---@field refresh_all string Refresh all servers
---@field help string Show help
---@field toggle_connection string Toggle server connection

---@class TableHelpersConfig
---@field sqlserver table<string, string>? SQL Server helper templates
---@field postgres table<string, string>? PostgreSQL helper templates
---@field mysql table<string, string>? MySQL helper templates
---@field sqlite table<string, string>? SQLite helper templates

---@class PerformanceConfig
---@field lazy_load boolean Enable lazy loading (default: true)
---@field page_size number Number of items to load per page (0 = load all)
---@field async boolean Use async operations where possible (default: true)

---Default configuration
---@type SsnsConfig
local default_config = {
  connections = {
    -- Example:
    -- dev = "sqlserver://localhost/DevDB",
    -- prod = "sqlserver://user:pass@server\\SQLEXPRESS/ProductionDB",
    -- postgres_local = "postgres://postgres:password@localhost:5432/mydb",
    -- mysql_local = "mysql://root@localhost/mydb",
    -- sqlite_local = "sqlite://./data/app.db",
  },

  ui = {
    position = "left",  -- "left", "right", "float"
    width = 40,
    height = 30,  -- Only used for float
    ssms_style = true,
    show_schema_prefix = true,
    auto_expand_depth = nil,  -- nil = don't auto-expand
    smart_cursor_positioning = true,  -- Enable smart cursor positioning on j/k
    show_help = true,  -- Show help text at top of tree
    -- Divider between multiple result sets
    -- Format: supports repeat patterns (N<char>), raw strings, variables, and auto-width
    -- Repeat: "20#" = 20 hashes, "10-" = 10 dashes
    -- Auto-width: "%fit%" = matches longest line width
    -- Multi-line: use \n (newline character, e.g., "20#\n20#\n20#")
    -- Variables: %row_count%, %col_count%, %run_time%, %result_set_num%, %total_result_sets%, %date%, %time%, %fit%
    -- Examples:
    --   "5-(%row_count% rows)5-" → "-----(11 rows)-----"
    --   "%fit%=\n---- Result Set %result_set_num% (%row_count% rows, %run_time%) ----\n%fit%="
    result_set_divider = "",
    show_result_set_info = false,  -- Show divider/info before first result set and single result sets

    icons = {
      -- Nerd Font icons (safe Unicode encoding)
      server = "\u{f233}",      --  (default/unknown)

      -- Database-type specific server icons
      server_sqlserver = "\u{e272}",   --  (SQL Server)
      server_postgres = "\u{e76e}",    --  (PostgreSQL)
      server_mysql = "\u{e704}",       --  (MySQL)
      server_sqlite = "\u{e7c4}",      --  (SQLite)
      server_bigquery = "\u{e7b2}",    --  (BigQuery)

      database = "\u{f1c0}",    --
      schema = "\u{f07b}",      --
      table = "\u{f0ce}",       --
      view = "\u{f06e}",        --
      procedure = "\u{f013}",   --
      ["function"] = "\u{0192}", -- ƒ
      column = "\u{f0ca}",      --
      index = "\u{f0e7}",       --
      key = "\u{f084}",         --
      parameter = "\u{f12e}",   --
      action = "\u{f04b}",      --
      sequence = "\u{f292}",    --
      synonym = "\u{f0c1}",     --

      -- Status indicators
      connected = "\u{f00c}",      --
      disconnected = "\u{f00d}",   --
      connecting = "\u{f110}",     --
      error = "\u{f026}",          --

      -- Tree expand/collapse
      expanded = "\u{f078}",    --
      collapsed = "\u{f054}",   --
    },

    highlights = {
      -- Server type-specific highlights (by database type)
      server_sqlserver = { fg = "#569CD6", bold = true },  -- Blue (SQL Server)
      server_postgres = { fg = "#4EC9B0", bold = true },   -- Cyan (PostgreSQL)
      server_mysql = { fg = "#CE9178", bold = true },      -- Orange (MySQL)
      server_sqlite = { fg = "#B5CEA8", bold = true },     -- Green (SQLite)
      server_bigquery = { fg = "#C586C0", bold = true },   -- Purple (BigQuery)
      server = { fg = "#808080", bold = true },            -- Gray (unknown/default)

      -- Object type highlights
      database = { fg = "#9CDCFE" },                       -- Light Blue (databases)
      schema = { fg = "#C586C0" },                         -- Purple (schemas)
      table = { fg = "#4FC1FF" },                          -- Bright Blue (tables)
      view = { fg = "#DCDCAA" },                           -- Yellow (views)
      procedure = { fg = "#CE9178" },                      -- Orange (procedures)
      ["function"] = { fg = "#4EC9B0" },                   -- Cyan (functions)
      column = { fg = "#9CDCFE" },                         -- Light Blue (columns)
      index = { fg = "#D7BA7D" },                          -- Gold (indexes)
      key = { fg = "#569CD6" },                            -- Blue (keys)
      parameter = { fg = "#DCDCAA" },                      -- Yellow (parameters)
      sequence = { fg = "#B5CEA8" },                       -- Green (sequences)
      synonym = { fg = "#808080" },                        -- Gray (synonyms)
      action = { fg = "#C586C0" },                         -- Purple (actions)
      group = { fg = "#858585", bold = true },             -- Gray bold (groups)

      -- Status highlights
      status_connected = { fg = "#4EC9B0", bold = true },  -- Green/cyan
      status_disconnected = { fg = "#808080" },            -- Gray
      status_connecting = { fg = "#DCDCAA" },              -- Yellow
      status_error = { fg = "#F48771", bold = true },      -- Red

      -- Tree expand/collapse indicators
      expanded = { fg = "#808080" },                       -- Gray
      collapsed = { fg = "#808080" },                      -- Gray
    },
  },

  cache = {
    ttl = 300,  -- 5 minutes
    enabled = true,  -- Enable query result caching
  },

  query = {
    default_limit = 100,  -- Default LIMIT for SELECT queries (0 = no limit)
    timeout = 30000,  -- Query timeout in milliseconds (30 seconds, 0 = no timeout)
    auto_execute_on_open = false,  -- Auto-execute query when opening action
  },

  keymaps = {
    toggle = "<CR>",  -- Toggle expand/collapse or execute action
    execute = "<Leader>r",  -- Execute query
    execute_selection = "<Leader>r",  -- Execute visual selection (in visual mode)
    save_query = "<Leader>s",  -- Save query to file
    close = "q",  -- Close SSNS window
    refresh = "r",  -- Refresh current node
    refresh_all = "R",  -- Refresh all servers
    help = "?",  -- Show help
    toggle_connection = "S",  -- Toggle server connection
  },

  table_helpers = {
    sqlserver = {
      ["SELECT Top 100"] = "SELECT TOP 100 * FROM {table};",
      ["SELECT Top 1000"] = "SELECT TOP 1000 * FROM {table};",
      ["Count"] = "SELECT COUNT(*) AS row_count FROM {table};",
      ["Describe"] = "EXEC sp_help '{table}';",
      ["INSERT Template"] = "INSERT INTO {table} ({columns})\nVALUES ({values});",
      ["UPDATE Template"] = "UPDATE {table}\nSET {column} = {value}\nWHERE {condition};",
      ["DELETE Template"] = "DELETE FROM {table}\nWHERE {condition};",
    },
    postgres = {
      ["SELECT Limit 100"] = "SELECT * FROM {table} LIMIT 100;",
      ["SELECT Limit 1000"] = "SELECT * FROM {table} LIMIT 1000;",
      ["Count"] = "SELECT COUNT(*) AS row_count FROM {table};",
      ["Describe"] = "\\d+ {table}",
      ["INSERT Template"] = "INSERT INTO {table} ({columns})\nVALUES ({values})\nRETURNING *;",
      ["UPDATE Template"] = "UPDATE {table}\nSET {column} = {value}\nWHERE {condition}\nRETURNING *;",
      ["DELETE Template"] = "DELETE FROM {table}\nWHERE {condition};",
    },
    mysql = {
      ["SELECT Limit 100"] = "SELECT * FROM {table} LIMIT 100;",
      ["SELECT Limit 1000"] = "SELECT * FROM {table} LIMIT 1000;",
      ["Count"] = "SELECT COUNT(*) AS row_count FROM {table};",
      ["Describe"] = "DESCRIBE {table};",
      ["INSERT Template"] = "INSERT INTO {table} ({columns})\nVALUES ({values});",
      ["UPDATE Template"] = "UPDATE {table}\nSET {column} = {value}\nWHERE {condition};",
      ["DELETE Template"] = "DELETE FROM {table}\nWHERE {condition};",
    },
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

  performance = {
    lazy_load = true,  -- Enable lazy loading
    page_size = 0,  -- Number of items per page (0 = load all)
    async = true,  -- Use async operations
  },
}

---@class Config
local Config = {}

---Current configuration (starts with defaults)
---@type SsnsConfig
Config.current = vim.deepcopy(default_config)

---Setup configuration
---@param user_config SsnsConfig? User configuration (merged with defaults)
function Config.setup(user_config)
  if user_config then
    Config.current = vim.tbl_deep_extend("force", default_config, user_config)
  else
    Config.current = vim.deepcopy(default_config)
  end

  -- Update cache TTL
  local Cache = require('ssns.cache')
  Cache.default_ttl = Config.current.cache.ttl
end

---Get current configuration
---@return SsnsConfig
function Config.get()
  return Config.current
end

---Get UI configuration
---@return UiConfig
function Config.get_ui()
  return Config.current.ui
end

---Get cache configuration
---@return CacheConfig
function Config.get_cache()
  return Config.current.cache
end

---Get connections configuration
---@return table<string, string>
function Config.get_connections()
  return Config.current.connections
end

---Add a connection
---@param name string Connection name
---@param connection_string string Connection string
function Config.add_connection(name, connection_string)
  Config.current.connections[name] = connection_string
end

---Remove a connection
---@param name string Connection name
function Config.remove_connection(name)
  Config.current.connections[name] = nil
end

---Get a specific icon
---@param icon_name string Icon name (server, database, table, etc.)
---@return string icon The icon character
function Config.get_icon(icon_name)
  return Config.current.ui.icons[icon_name] or ""
end

---Get query configuration
---@return QueryConfig
function Config.get_query()
  return Config.current.query
end

---Get keymaps configuration
---@return KeymapsConfig
function Config.get_keymaps()
  return Config.current.keymaps
end

---Get table helpers configuration for a specific database type
---@param db_type string Database type (sqlserver, postgres, mysql, sqlite)
---@return table<string, string>?
function Config.get_table_helpers(db_type)
  return Config.current.table_helpers[db_type]
end

---Get performance configuration
---@return PerformanceConfig
function Config.get_performance()
  return Config.current.performance
end

---Validate configuration
---@param config SsnsConfig
---@return boolean valid
---@return string? error_message
function Config.validate(config)
  -- Check required fields
  if not config.ui then
    return false, "Missing 'ui' configuration"
  end

  if not config.ui.position then
    return false, "Missing 'ui.position' configuration"
  end

  -- Validate position
  local valid_positions = { left = true, right = true, float = true }
  if not valid_positions[config.ui.position] then
    return false, string.format("Invalid ui.position: %s (must be 'left', 'right', or 'float')", config.ui.position)
  end

  -- Validate width
  if not config.ui.width or config.ui.width < 10 then
    return false, "ui.width must be at least 10"
  end

  -- Validate cache configuration
  if not config.cache or not config.cache.ttl or config.cache.ttl < 0 then
    return false, "cache.ttl must be a positive number"
  end

  -- Validate query configuration
  if config.query then
    if config.query.default_limit and config.query.default_limit < 0 then
      return false, "query.default_limit must be non-negative"
    end
    if config.query.timeout and config.query.timeout < 0 then
      return false, "query.timeout must be non-negative"
    end
  end

  -- Validate performance configuration
  if config.performance then
    if config.performance.page_size and config.performance.page_size < 0 then
      return false, "performance.page_size must be non-negative"
    end
  end

  return true, nil
end

---Reset to default configuration
function Config.reset()
  Config.current = vim.deepcopy(default_config)
end

---Get default configuration (for documentation)
---@return SsnsConfig
function Config.get_default()
  return vim.deepcopy(default_config)
end

return Config
