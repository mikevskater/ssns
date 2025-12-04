---@class ViewUsageWeights
---View usage-based ranking weights in a floating window
---Displays tracked items and their weights for completion ranking
---@module ssns.features.view_usage_weights
local ViewUsageWeights = {}

local UiFloat = require('ssns.ui.float')
local JsonUtils = require('ssns.utils.json')
local UsageTracker = require('ssns.completion.usage_tracker')

-- Store reference to current floating window for cleanup
local current_float = nil

---Close the current floating window
function ViewUsageWeights.close_current_float()
  if current_float then
    if current_float.close then
      pcall(function() current_float:close() end)
    end
  end
  current_float = nil
end

---Format weight data for display
---@param data any Weight data (number or table with weight field)
---@return number weight
---@return string? last_used
local function extract_weight_info(data)
  if type(data) == "table" then
    return data.weight or 0, data.last_used
  end
  return data or 0, nil
end

---Get top N items from a type sorted by weight
---@param type_data table<string, any>
---@param limit number
---@return table[] items
local function get_top_items(type_data, limit)
  local items = {}
  for path, data in pairs(type_data) do
    local weight, last_used = extract_weight_info(data)
    table.insert(items, {
      path = path,
      weight = weight,
      last_used = last_used,
    })
  end

  table.sort(items, function(a, b) return a.weight > b.weight end)

  local result = {}
  for i = 1, math.min(limit, #items) do
    table.insert(result, items[i])
  end
  return result
end

---View usage weights
function ViewUsageWeights.view_weights()
  -- Close any existing float
  ViewUsageWeights.close_current_float()

  -- Ensure initialized
  if not UsageTracker.initialized then
    UsageTracker.init()
  end

  -- Build display content
  local display_lines = {}

  table.insert(display_lines, "Usage-Based Ranking Weights")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  -- File info
  table.insert(display_lines, "Persistence File")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, string.format("  Path: %s", UsageTracker.persist_file))
  table.insert(display_lines, string.format("  Dirty: %s", UsageTracker.is_dirty and "Yes (unsaved changes)" or "No"))
  if UsageTracker.weights.saved_at then
    table.insert(display_lines, string.format("  Last saved: %s", UsageTracker.weights.saved_at))
  end
  table.insert(display_lines, "")

  -- Global statistics
  local stats = UsageTracker.get_stats()
  table.insert(display_lines, "Global Statistics")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, string.format("  Total tracked items: %d", stats.total_items))
  table.insert(display_lines, "")

  table.insert(display_lines, "  By type:")
  local type_order = { "database", "schema", "table", "column", "procedure", "function" }
  for _, type_key in ipairs(type_order) do
    local count = stats.by_type[type_key] or 0
    if count > 0 then
      table.insert(display_lines, string.format("    %s: %d", type_key, count))
    end
  end
  table.insert(display_lines, "")

  -- Top tables (from stats)
  if #stats.top_tables > 0 then
    table.insert(display_lines, "Top 10 Tables (by weight)")
    table.insert(display_lines, string.rep("-", 30))
    for i, item in ipairs(stats.top_tables) do
      table.insert(display_lines, string.format("  %2d. [%4d] %s", i, item.weight, item.path))
    end
    table.insert(display_lines, "")
  end

  -- Connection breakdown
  table.insert(display_lines, "Weights by Connection")
  table.insert(display_lines, string.rep("-", 30))

  local connections = UsageTracker.weights.connections
  if not next(connections) then
    table.insert(display_lines, "  (No usage data recorded)")
    table.insert(display_lines, "")
  else
    -- Sort connections
    local sorted_conns = {}
    for conn_key in pairs(connections) do
      table.insert(sorted_conns, conn_key)
    end
    table.sort(sorted_conns)

    for _, conn_key in ipairs(sorted_conns) do
      local conn_data = connections[conn_key]
      table.insert(display_lines, "")
      table.insert(display_lines, string.format("  Connection: %s", conn_key))

      -- Count items per type
      local type_counts = {}
      local total_weight = 0
      for type_key, type_data in pairs(conn_data) do
        local count = 0
        for _, data in pairs(type_data) do
          count = count + 1
          local weight = extract_weight_info(data)
          total_weight = total_weight + weight
        end
        if count > 0 then
          type_counts[type_key] = count
        end
      end

      table.insert(display_lines, string.format("    Total weight: %d", total_weight))
      table.insert(display_lines, "")

      -- Show each type with top items
      for _, type_key in ipairs(type_order) do
        local type_data = conn_data[type_key]
        local count = type_counts[type_key]
        if type_data and count and count > 0 then
          table.insert(display_lines, string.format("    %s (%d items):", type_key:upper(), count))

          local top_items = get_top_items(type_data, 5)
          for _, item in ipairs(top_items) do
            local extra = ""
            if item.last_used then
              extra = string.format(" (last: %s)", item.last_used)
            end
            -- Truncate long paths
            local display_path = item.path
            if #display_path > 45 then
              display_path = "..." .. display_path:sub(-42)
            end
            table.insert(display_lines, string.format("      [%4d] %s%s", item.weight, display_path, extra))
          end

          if count > 5 then
            table.insert(display_lines, string.format("      ... and %d more", count - 5))
          end
          table.insert(display_lines, "")
        end
      end
    end
  end

  -- JSON output for full data
  table.insert(display_lines, "")
  table.insert(display_lines, "Full Data JSON")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  -- Create a summary structure for JSON
  local json_data = {
    persist_file = UsageTracker.persist_file,
    is_dirty = UsageTracker.is_dirty,
    saved_at = UsageTracker.weights.saved_at,
    stats = stats,
    connections_count = 0,
    connections = {},
  }

  -- Add connection summaries (not full data to keep JSON readable)
  for conn_key, conn_data in pairs(connections) do
    json_data.connections_count = json_data.connections_count + 1
    local conn_summary = {}
    for type_key, type_data in pairs(conn_data) do
      local items = {}
      for path, data in pairs(type_data) do
        items[path] = extract_weight_info(data)
      end
      -- Only include if non-empty
      if next(items) then
        conn_summary[type_key] = items
      end
    end
    json_data.connections[conn_key] = conn_summary
  end

  local json_lines = JsonUtils.prettify_lines(json_data)
  for _, line in ipairs(json_lines) do
    table.insert(display_lines, line)
  end

  -- Create floating window
  current_float = UiFloat.create(display_lines, {
    title = "Usage Weights",
    border = "rounded",
    filetype = "json",
    min_width = 70,
    max_width = 120,
    max_height = 45,
    wrap = false,
    keymaps = {
      ['r'] = function()
        -- Refresh display
        ViewUsageWeights.view_weights()
      end,
      ['s'] = function()
        -- Save to file
        local success = UsageTracker.save_to_file()
        if success then
          vim.notify("SSNS: Usage weights saved", vim.log.levels.INFO)
        else
          vim.notify("SSNS: Failed to save usage weights", vim.log.levels.ERROR)
        end
        ViewUsageWeights.view_weights()
      end,
      ['C'] = function()
        -- Clear all weights (with confirmation)
        vim.ui.input({ prompt = "Clear ALL usage weights? (y/N): " }, function(input)
          if input and input:lower() == "y" then
            UsageTracker.clear_weights(nil)
            vim.notify("SSNS: All usage weights cleared", vim.log.levels.INFO)
            ViewUsageWeights.view_weights()
          end
        end)
      end,
    },
    footer = "q: close | r: refresh | s: save now | C: clear all (confirm)",
  })
end

return ViewUsageWeights
