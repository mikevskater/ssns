---@class SsnsConfig
---@field connections table<string, string> Map of connection names to connection strings
---@field ui UiConfig UI configuration
---@field cache CacheConfig Cache configuration
---@field backend BackendConfig Backend configuration

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

---@class CacheConfig
---@field ttl number Time to live in seconds for cached data

---@class BackendConfig
---@field use_nodejs boolean Use Node.js backend instead of vim-dadbod (Phase 7)

---Default configuration
---@type SsnsConfig
local default_config = {
  connections = {
    -- Example:
    -- dev = "sqlserver://localhost/DevDB",
    -- prod = "sqlserver://user:pass@server\\SQLEXPRESS/ProductionDB",
  },

  ui = {
    position = "left",  -- "left", "right", "float"
    width = 40,
    height = nil,  -- Only used for float
    ssms_style = true,
    show_schema_prefix = true,
    auto_expand_depth = nil,  -- nil = don't auto-expand
    smart_cursor_positioning = true,  -- Enable smart cursor positioning on j/k
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
      server = "",
      database = "",
      schema = "",
      table = "",
      view = "",
      procedure = "",
      ["function"] = "",
      column = "",
      index = "",
      key = "",
      action = "",
    },
  },

  cache = {
    ttl = 300,  -- 5 minutes
  },

  backend = {
    use_nodejs = true,  -- Use Node.js backend (Phase 7) - set to false to use vim-dadbod
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

---Get backend configuration
---@return BackendConfig
function Config.get_backend()
  return Config.current.backend
end

---Check if Node.js backend should be used
---@return boolean
function Config.use_nodejs()
  return Config.current.backend and Config.current.backend.use_nodejs or false
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

  -- Validate cache TTL
  if not config.cache or not config.cache.ttl or config.cache.ttl < 0 then
    return false, "cache.ttl must be a positive number"
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
