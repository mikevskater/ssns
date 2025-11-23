---@class UsageWeightData
---Weight data for a single item
---@field weight number Weight value
---@field last_used string? Last used timestamp (for databases)

---@class UsageConnectionData
---Usage data for a single connection
---@field database table<string, UsageWeightData> Database weights
---@field schema table<string, UsageWeightData> Schema weights
---@field table table<string, UsageWeightData> Table weights
---@field column table<string, UsageWeightData> Column weights
---@field procedure table<string, UsageWeightData> Procedure weights
---@field ["function"] table<string, UsageWeightData> Function weights

---@class UsageTrackerData
---Persistent storage structure
---@field version number Data format version
---@field saved_at string Last save timestamp
---@field connections table<string, UsageConnectionData> Connection -> Usage data

---@class UsageTracker
---Usage-based ranking tracker for SQL completion
local UsageTracker = {}

-- Module state
UsageTracker.weights = { connections = {} }
UsageTracker.persist_file = vim.fn.stdpath('data') .. '/ssns/completion_usage.json'
UsageTracker.is_dirty = false
UsageTracker.save_timer = nil
UsageTracker.initialized = false

-- Config and debug modules (lazy loaded)
local Config = nil
local Debug = nil

---Debug logging helper
---@param message string
local function debug_log(message)
  if not Debug then
    Debug = require('ssns.debug')
  end

  if not Config then
    Config = require('ssns.config')
  end

  local config = Config.get()
  if config.completion and config.completion.debug then
    Debug.log("[USAGE] " .. message)
  end
end

---Extract connection key from connection object
---Removes credentials from connection string for privacy
---@param connection table Connection context object with connection_string field
---@return string connection_key
local function _get_connection_key(connection)
  if not connection or not connection.connection_string then
    return ""
  end

  local conn_str = connection.connection_string

  -- Remove credentials: user:pass@host -> host
  local without_creds = conn_str:gsub("://[^:]+:[^@]+@", "://")

  return without_creds
end

---Ensure nested structure exists for connection
---@param connection_key string
local function _ensure_connection_structure(connection_key)
  if not UsageTracker.weights.connections[connection_key] then
    UsageTracker.weights.connections[connection_key] = {
      database = {},
      schema = {},
      table = {},
      column = {},
      procedure = {},
      ["function"] = {},
    }
    debug_log(string.format("Created structure for connection: %s", connection_key))
  end
end

---Apply time-based decay to weights
---Reduces weights based on time elapsed since last save
local function _apply_decay()
  if not Config then
    Config = require('ssns.config')
  end

  local config = Config.get()
  local decay_factor = config.completion.usage_weight_decay

  if not decay_factor or decay_factor <= 0 or decay_factor >= 1 then
    return
  end

  -- Calculate days since last save
  local last_saved = UsageTracker.weights.saved_at
  if not last_saved then
    return
  end

  -- Parse saved_at timestamp (YYYY-MM-DD HH:MM:SS)
  local year, month, day, hour, min, sec = last_saved:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
  if not year then
    return
  end

  local saved_time = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec)
  })

  local current_time = os.time()
  local days_elapsed = (current_time - saved_time) / (24 * 60 * 60)

  if days_elapsed <= 0 then
    return
  end

  -- Apply decay: weight = weight * (decay_factor ^ days_elapsed)
  local decay_multiplier = math.pow(decay_factor, days_elapsed)
  local items_decayed = 0

  for conn_key, conn_data in pairs(UsageTracker.weights.connections) do
    for type_key, type_data in pairs(conn_data) do
      for path, data in pairs(type_data) do
        local old_weight = data.weight or data
        local new_weight = math.floor(old_weight * decay_multiplier)

        if new_weight ~= old_weight then
          if type(data) == "table" then
            data.weight = new_weight
          else
            type_data[path] = new_weight
          end
          items_decayed = items_decayed + 1
        end
      end
    end
  end

  if items_decayed > 0 then
    debug_log(string.format("Applied decay to %d items (factor: %.2f, days: %.1f)",
      items_decayed, decay_factor, days_elapsed))
  end
end

---Prune weights to respect max_items limit
---Keeps only top N items by weight per type
local function _prune_weights()
  if not Config then
    Config = require('ssns.config')
  end

  local config = Config.get()
  local max_items = config.completion.usage_max_items or 10000

  if max_items <= 0 then
    return  -- No limit
  end

  for conn_key, conn_data in pairs(UsageTracker.weights.connections) do
    for type_key, type_data in pairs(conn_data) do
      -- Count items
      local items = {}
      for path, data in pairs(type_data) do
        local weight = type(data) == "table" and data.weight or data
        table.insert(items, { path = path, weight = weight, data = data })
      end

      -- If over limit, keep only top N
      if #items > max_items then
        -- Sort by weight descending
        table.sort(items, function(a, b) return a.weight > b.weight end)

        -- Keep only top max_items
        local pruned = {}
        for i = 1, math.min(max_items, #items) do
          pruned[items[i].path] = items[i].data
        end

        UsageTracker.weights.connections[conn_key][type_key] = pruned
        debug_log(string.format("Pruned %s.%s weights from %d to %d items",
          conn_key, type_key, #items, max_items))
      end
    end
  end
end

---Setup auto-save timer and autocmd
local function _setup_auto_save()
  if not Config then
    Config = require('ssns.config')
  end

  local config = Config.get()

  if not config.completion.usage_auto_save then
    debug_log("Auto-save disabled")
    return
  end

  local interval = (config.completion.usage_save_interval or 30) * 1000  -- Convert to ms

  -- Create timer for periodic saves
  UsageTracker.save_timer = vim.loop.new_timer()
  UsageTracker.save_timer:start(interval, interval, vim.schedule_wrap(function()
    if UsageTracker.is_dirty then
      debug_log("Auto-saving (timer)")
      UsageTracker.save_to_file()
    end
  end))

  -- Save on exit
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('SSNSUsageTrackerSave', { clear = true }),
    callback = function()
      if UsageTracker.is_dirty then
        debug_log("Auto-saving (VimLeavePre)")
        UsageTracker.save_to_file()
      end
    end
  })

  debug_log(string.format("Auto-save enabled (interval: %ds)", interval / 1000))
end

---Initialize the usage tracker
---Creates data directory and loads from file
---@return boolean success
function UsageTracker.init()
  if UsageTracker.initialized then
    return true
  end

  -- Create data directory if needed
  local data_dir = vim.fn.stdpath('data') .. '/ssns'
  vim.fn.mkdir(data_dir, 'p')

  -- Load from file if exists
  UsageTracker.load_from_file()

  -- Setup auto-save
  _setup_auto_save()

  UsageTracker.initialized = true
  debug_log("UsageTracker initialized")

  return true
end

---Record a completion selection
---Increments weight and updates timestamp
---@param connection table Connection context object with connection_string field
---@param item_type string Type: "database", "schema", "table", "column", "procedure", "function"
---@param item_path string Full qualified path (e.g., "AdventureWorks.dbo.Employees.EmployeeID")
---@return boolean success
function UsageTracker.record_selection(connection, item_type, item_path)
  if not connection or not item_type or not item_path then
    return false
  end

  -- Ensure initialized
  if not UsageTracker.initialized then
    UsageTracker.init()
  end

  local connection_key = _get_connection_key(connection)
  if connection_key == "" then
    debug_log("Invalid connection key")
    return false
  end

  -- Ensure structure exists
  _ensure_connection_structure(connection_key)

  local conn_data = UsageTracker.weights.connections[connection_key]
  local type_data = conn_data[item_type]

  if not type_data then
    debug_log(string.format("Invalid item type: %s", item_type))
    return false
  end

  -- Get current weight
  local current_data = type_data[item_path]
  local current_weight = 0

  if current_data then
    current_weight = type(current_data) == "table" and current_data.weight or current_data
  end

  -- Get increment from config
  if not Config then
    Config = require('ssns.config')
  end
  local config = Config.get()
  local increment = config.completion.usage_weight_increment or 1

  -- Increment weight
  local new_weight = current_weight + increment

  -- Update data (databases get last_used timestamp)
  if item_type == "database" then
    type_data[item_path] = {
      weight = new_weight,
      last_used = os.date("%Y-%m-%d %H:%M:%S")
    }
  else
    type_data[item_path] = { weight = new_weight }
  end

  -- Mark as dirty
  UsageTracker.is_dirty = true

  debug_log(string.format("Recorded: %s.%s (%s) -> %d (+%d)",
    connection_key, item_type, item_path, new_weight, increment))

  return true
end

---Get weight for an item
---@param connection table Connection context object with connection_string field
---@param item_type string Type: "database", "schema", "table", "column", "procedure", "function"
---@param item_path string Full qualified path
---@return number weight Weight value (0 if not found)
function UsageTracker.get_weight(connection, item_type, item_path)
  if not connection or not item_type or not item_path then
    return 0
  end

  -- Ensure initialized
  if not UsageTracker.initialized then
    UsageTracker.init()
  end

  local connection_key = _get_connection_key(connection)
  if connection_key == "" then
    return 0
  end

  local conn_data = UsageTracker.weights.connections[connection_key]
  if not conn_data then
    return 0
  end

  local type_data = conn_data[item_type]
  if not type_data then
    return 0
  end

  local data = type_data[item_path]
  if not data then
    return 0
  end

  return type(data) == "table" and data.weight or data
end

---Get all weights for a specific type
---@param connection table Connection context object with connection_string field
---@param item_type string Type to get weights for
---@return table<string, number> Map of path -> weight
function UsageTracker.get_all_weights(connection, item_type)
  local weights = {}

  if not connection or not item_type then
    return weights
  end

  -- Ensure initialized
  if not UsageTracker.initialized then
    UsageTracker.init()
  end

  local connection_key = _get_connection_key(connection)
  if connection_key == "" then
    return weights
  end

  local conn_data = UsageTracker.weights.connections[connection_key]
  if not conn_data then
    return weights
  end

  local type_data = conn_data[item_type]
  if not type_data then
    return weights
  end

  -- Extract weights from data
  for path, data in pairs(type_data) do
    weights[path] = type(data) == "table" and data.weight or data
  end

  return weights
end

---Clear all weights for a connection (or all if nil)
---@param connection_key string? Optional connection string key (nil = clear all)
---@return boolean success
function UsageTracker.clear_weights(connection_key)
  -- Ensure initialized
  if not UsageTracker.initialized then
    UsageTracker.init()
  end

  if connection_key then
    -- Clear specific connection
    if UsageTracker.weights.connections[connection_key] then
      UsageTracker.weights.connections[connection_key] = nil
      UsageTracker.is_dirty = true
      debug_log(string.format("Cleared weights for: %s", connection_key))

      -- Auto-save
      if not Config then
        Config = require('ssns.config')
      end
      local config = Config.get()
      if config.completion.usage_auto_save then
        UsageTracker.save_to_file()
      end

      return true
    else
      debug_log(string.format("No weights found for: %s", connection_key))
      return false
    end
  else
    -- Clear all connections
    UsageTracker.weights.connections = {}
    UsageTracker.is_dirty = true
    debug_log("Cleared all weights")

    -- Auto-save
    if not Config then
      Config = require('ssns.config')
    end
    local config = Config.get()
    if config.completion.usage_auto_save then
      UsageTracker.save_to_file()
    end

    return true
  end
end

---Save weights to JSON file
---@return boolean success
function UsageTracker.save_to_file()
  -- Ensure initialized
  if not UsageTracker.initialized then
    UsageTracker.init()
  end

  -- Prune if needed
  _prune_weights()

  -- Create data structure
  local data = {
    version = 1,
    saved_at = os.date("%Y-%m-%d %H:%M:%S"),
    connections = UsageTracker.weights.connections
  }

  -- Encode to JSON
  local ok, json = pcall(vim.fn.json_encode, data)
  if not ok then
    debug_log("Failed to encode usage data: " .. tostring(json))
    return false
  end

  -- Write to temp file first (atomic write)
  local temp_file = UsageTracker.persist_file .. '.tmp'
  local f = io.open(temp_file, 'w')
  if not f then
    debug_log("Failed to open temp file for writing: " .. temp_file)
    return false
  end

  f:write(json)
  f:close()

  -- On Windows, os.rename fails if target exists, so remove it first
  os.remove(UsageTracker.persist_file)

  -- Rename temp to actual file (atomic operation)
  local rename_ok = os.rename(temp_file, UsageTracker.persist_file)
  if not rename_ok then
    debug_log("Failed to rename temp file")
    -- Try to remove temp file
    os.remove(temp_file)
    return false
  end

  UsageTracker.is_dirty = false
  debug_log("Saved usage data to file")

  return true
end

---Load weights from JSON file
---@return boolean success
function UsageTracker.load_from_file()
  local f = io.open(UsageTracker.persist_file, 'r')
  if not f then
    -- File doesn't exist yet, not an error
    debug_log("No existing usage data file")
    return true
  end

  local content = f:read('*a')
  f:close()

  if not content or content == "" then
    debug_log("Empty usage data file")
    return true
  end

  -- Parse JSON
  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or not data then
    debug_log("Failed to parse usage data file")
    return false
  end

  -- Validate version
  if data.version ~= 1 then
    debug_log(string.format("Unsupported data version: %s", tostring(data.version)))
    return false
  end

  -- Load weights
  UsageTracker.weights.connections = data.connections or {}
  UsageTracker.weights.saved_at = data.saved_at

  -- Apply decay if configured
  _apply_decay()

  -- Count loaded items
  local total_items = 0
  for _, conn_data in pairs(UsageTracker.weights.connections) do
    for _, type_data in pairs(conn_data) do
      for _ in pairs(type_data) do
        total_items = total_items + 1
      end
    end
  end

  debug_log(string.format("Loaded %d items from file", total_items))

  return true
end

---Get statistics for a connection
---@param connection table? Connection context object (nil = all connections)
---@return table stats Statistics object
function UsageTracker.get_stats(connection)
  -- Ensure initialized
  if not UsageTracker.initialized then
    UsageTracker.init()
  end

  local stats = {
    total_items = 0,
    by_type = {
      database = 0,
      schema = 0,
      table = 0,
      column = 0,
      procedure = 0,
      ["function"] = 0,
    },
    top_tables = {},
  }

  local connection_key = nil
  if connection then
    connection_key = _get_connection_key(connection)
  end

  -- Collect all tables with weights
  local all_tables = {}

  -- Iterate connections
  for conn_key, conn_data in pairs(UsageTracker.weights.connections) do
    -- Filter by connection if specified
    if not connection_key or conn_key == connection_key then
      for type_key, type_data in pairs(conn_data) do
        for path, data in pairs(type_data) do
          local weight = type(data) == "table" and data.weight or data

          stats.total_items = stats.total_items + 1
          stats.by_type[type_key] = (stats.by_type[type_key] or 0) + 1

          -- Collect table weights
          if type_key == "table" then
            table.insert(all_tables, { path = path, weight = weight })
          end
        end
      end
    end
  end

  -- Sort tables by weight descending and take top 10
  table.sort(all_tables, function(a, b) return a.weight > b.weight end)

  for i = 1, math.min(10, #all_tables) do
    table.insert(stats.top_tables, all_tables[i])
  end

  return stats
end

return UsageTracker
