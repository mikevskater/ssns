---Base class for completion providers
---Provides common functionality for error handling, usage weights, sorting, and validation
---@class BaseProvider
local BaseProvider = {}

local UsageTracker = require('ssns.completion.usage_tracker')
local Config = require('ssns.config')

---Get usage weight for an item
---Centralizes weight tracking configuration and error handling
---@param connection table Connection context
---@param item_type string Type ("table", "column", "schema", etc.)
---@param item_path string Full path to item
---@return number weight Usage weight (0 if not found or tracking disabled)
function BaseProvider.get_usage_weight(connection, item_type, item_path)
  local config = Config.get()

  -- If tracking disabled, return 0 (no weight)
  if not config.completion or not config.completion.track_usage then
    return 0
  end

  -- Get weight from UsageTracker
  local success, weight = pcall(function()
    return UsageTracker.get_weight(connection, item_type, item_path)
  end)

  if success then
    return weight or 0
  else
    return 0
  end
end

---Calculate priority from usage weight
---Higher weight = lower priority number = sorts first
---@param weight number Usage weight
---@param idx number Ordinal position for items without weight
---@param base_priority number? Base priority for no-weight items (default 5000)
---@return number priority Priority value for sortText
function BaseProvider.calculate_priority(weight, idx, base_priority)
  base_priority = base_priority or 5000

  if weight > 0 then
    -- Higher weight = lower priority number (sorts first)
    -- Range: 0-4999 for weighted items
    return math.max(0, 4999 - weight)
  else
    -- No weight, use iteration order
    -- Range: 5000+ for non-weighted items
    return base_priority + idx
  end
end

---Format sortText with priority and label
---@param priority number Priority value
---@param label string Item label
---@return string sortText Formatted sort text
function BaseProvider.format_sort_text(priority, label)
  return string.format("%05d_%s", priority, label)
end

---Apply usage weight to a completion item
---Updates sortText and stores weight in data
---@param item table Completion item to update
---@param connection table Connection context
---@param item_type string Type ("table", "column", etc.)
---@param item_path string Full path to item
---@param idx number Ordinal position
function BaseProvider.apply_usage_weight(item, connection, item_type, item_path, idx)
  local weight = BaseProvider.get_usage_weight(connection, item_type, item_path)
  local priority = BaseProvider.calculate_priority(weight, idx)

  item.sortText = BaseProvider.format_sort_text(priority, item.label)

  -- Store weight in data for debugging
  if item.data then
    item.data.weight = weight
  end
end

---Validate connection context
---@param ctx table Context from source
---@return boolean is_valid True if connection is valid
---@return table|nil connection Connection info if valid
function BaseProvider.validate_connection(ctx)
  local connection = ctx.connection
  if not connection then
    return false, nil
  end
  return true, connection
end

---Validate connection has server and database
---@param ctx table Context from source
---@return boolean is_valid True if server and database are valid
---@return table|nil server Server object if valid
---@return table|nil database Database object if valid
function BaseProvider.validate_server_database(ctx)
  local connection = ctx.connection
  if not connection then
    return false, nil, nil
  end

  local server = connection.server
  local database = connection.database

  if not server or not server:is_connected() then
    return false, nil, nil
  end

  if not database then
    return false, server, nil
  end

  return true, server, database
end

---Get target database (handles cross-database completion)
---@param server table Server object
---@param database table Current database object
---@param filter_database string? Database name for cross-db queries
---@return table|nil target_db Target database object
function BaseProvider.get_target_database(server, database, filter_database)
  local target_db = database

  if filter_database and server then
    target_db = server:get_database(filter_database)
    if target_db and not target_db.is_loaded then
      target_db:load()
    end
  end

  return target_db
end

---Create a safe completion wrapper with error handling
---This is the standard entry point pattern for all providers
---@param provider table The provider module
---@param provider_name string Name for error messages
---@param use_schedule boolean? Whether to use vim.schedule (default false)
---@return function get_completions The wrapped get_completions function
function BaseProvider.create_safe_wrapper(provider, provider_name, use_schedule)
  return function(ctx, callback)
    local success, result = pcall(function()
      return provider._get_completions_impl(ctx)
    end)

    local deliver_result = function()
      if success then
        callback(result or {})
      else
        if vim.g.ssns_debug then
          vim.notify(
            string.format("[SSNS Completion] %s error: %s", provider_name, tostring(result)),
            vim.log.levels.ERROR
          )
        end
        callback({})
      end
    end

    if use_schedule then
      vim.schedule(deliver_result)
    else
      deliver_result()
    end
  end
end

---Inject usage weights into a list of completion items
---Updates sortText for all items based on usage tracking
---@param items table[] Array of completion items
---@param connection table Connection context
---@param get_item_info function(item, idx) Returns item_type, item_path for each item
function BaseProvider.inject_usage_weights(items, connection, get_item_info)
  for idx, item in ipairs(items) do
    local item_type, item_path = get_item_info(item, idx)

    if item_path then
      BaseProvider.apply_usage_weight(item, connection, item_type, item_path, idx)
    end
  end
end

return BaseProvider
