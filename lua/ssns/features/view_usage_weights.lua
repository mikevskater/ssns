---@class ViewUsageWeights
---View usage-based ranking weights in a floating window
---Displays tracked items and their weights for completion ranking
---@module ssns.features.view_usage_weights
local ViewUsageWeights = {}

local UiFloat = require('ssns.ui.core.float')
local ContentBuilder = require('ssns.ui.core.content_builder')
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

  -- Build styled content
  local cb = ContentBuilder.new()

  cb:header("Usage-Based Ranking Weights")
  cb:separator("=", 50)
  cb:blank()

  -- File info
  cb:section("Persistence File")
  cb:separator("-", 30)
  cb:spans({
    { text = "  Path: ", style = "label" },
    { text = UsageTracker.persist_file, style = "value" },
  })
  cb:spans({
    { text = "  Dirty: ", style = "label" },
    { text = UsageTracker.is_dirty and "Yes (unsaved changes)" or "No", style = UsageTracker.is_dirty and "warning" or "success" },
  })
  if UsageTracker.weights.saved_at then
    cb:spans({
      { text = "  Last saved: ", style = "label" },
      { text = UsageTracker.weights.saved_at, style = "muted" },
    })
  end
  cb:blank()

  -- Global statistics
  local stats = UsageTracker.get_stats()
  cb:section("Global Statistics")
  cb:separator("-", 30)
  cb:spans({
    { text = "  Total tracked items: ", style = "label" },
    { text = tostring(stats.total_items), style = "number" },
  })
  cb:blank()

  cb:styled("  By type:", "label")
  local type_order = { "database", "schema", "table", "column", "procedure", "function" }
  for _, type_key in ipairs(type_order) do
    local count = stats.by_type[type_key] or 0
    if count > 0 then
      local style = type_key == "table" and "table" or type_key == "column" and "column" or
                    type_key == "database" and "database" or type_key == "schema" and "schema" or
                    type_key == "procedure" and "procedure" or type_key == "function" and "func" or "value"
      cb:spans({
        { text = "    " },
        { text = type_key, style = style },
        { text = ": " },
        { text = tostring(count), style = "number" },
      })
    end
  end
  cb:blank()

  -- Top tables (from stats)
  if #stats.top_tables > 0 then
    cb:section("Top 10 Tables (by weight)")
    cb:separator("-", 30)
    for i, item in ipairs(stats.top_tables) do
      cb:spans({
        { text = string.format("  %2d. ", i), style = "muted" },
        { text = string.format("[%4d] ", item.weight), style = "number" },
        { text = item.path, style = "table" },
      })
    end
    cb:blank()
  end

  -- Connection breakdown
  cb:section("Weights by Connection")
  cb:separator("-", 30)

  local connections = UsageTracker.weights.connections
  if not next(connections) then
    cb:styled("  (No usage data recorded)", "muted")
    cb:blank()
  else
    -- Sort connections
    local sorted_conns = {}
    for conn_key in pairs(connections) do
      table.insert(sorted_conns, conn_key)
    end
    table.sort(sorted_conns)

    for _, conn_key in ipairs(sorted_conns) do
      local conn_data = connections[conn_key]
      cb:blank()
      cb:spans({
        { text = "  Connection: ", style = "label" },
        { text = conn_key, style = "server" },
      })

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

      cb:spans({
        { text = "    Total weight: ", style = "label" },
        { text = tostring(total_weight), style = "number" },
      })
      cb:blank()

      -- Show each type with top items
      for _, type_key in ipairs(type_order) do
        local type_data = conn_data[type_key]
        local count = type_counts[type_key]
        if type_data and count and count > 0 then
          local type_style = type_key == "table" and "table" or type_key == "column" and "column" or
                            type_key == "database" and "database" or type_key == "schema" and "schema" or
                            type_key == "procedure" and "procedure" or "func"
          cb:spans({
            { text = "    " },
            { text = type_key:upper(), style = type_style },
            { text = " (" },
            { text = tostring(count), style = "number" },
            { text = " items):" },
          })

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
            cb:spans({
              { text = "      [" },
              { text = string.format("%4d", item.weight), style = "number" },
              { text = "] " },
              { text = display_path, style = "value" },
              { text = extra, style = "muted" },
            })
          end

          if count > 5 then
            cb:styled(string.format("      ... and %d more", count - 5), "muted")
          end
          cb:blank()
        end
      end
    end
  end

  -- JSON output for full data
  cb:blank()
  cb:header("Full Data JSON")
  cb:separator("=", 50)
  cb:blank()

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
    cb:line(line)
  end

  -- Create floating window
  current_float = UiFloat.create_styled(cb, {
    title = "Usage Weights",
    border = "rounded",
    min_width = 70,
    max_width = 120,
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
        -- Clear all weights (with confirmation dialog)
        local confirm_win = UiFloat.create({
          title = "Clear Usage Weights",
          width = 50,
          height = 8,
          center = true,
          content_builder = true,
          zindex = UiFloat.ZINDEX.MODAL,
        })

        if confirm_win then
          local cb = confirm_win:get_content_builder()
          cb:line("")
          cb:line("  ⚠ Clear ALL usage weights?", "WarningMsg")
          cb:line("  This cannot be undone.", "SsnsUiHint")
          cb:line("")
          cb:line("  Press <Enter> to confirm, <Esc> to cancel", "Comment")
          confirm_win:render()

          local confirm_keymaps = {
            ["<CR>"] = function()
              confirm_win:close()
              UsageTracker.clear_weights(nil)
              vim.notify("SSNS: All usage weights cleared", vim.log.levels.INFO)
              ViewUsageWeights.view_weights()
            end,
            ["<Esc>"] = function() confirm_win:close() end,
            ["q"] = function() confirm_win:close() end,
            ["n"] = function() confirm_win:close() end,
          }
          for key, fn in pairs(confirm_keymaps) do
            vim.keymap.set("n", key, fn, { buffer = confirm_win.buf, nowait = true })
          end
        end
      end,
    },
    footer = "q: close | r: refresh | s: save now | C: clear all (confirm)",
  })
end

return ViewUsageWeights

