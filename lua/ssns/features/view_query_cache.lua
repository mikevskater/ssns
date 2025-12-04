---@class ViewQueryCache
---View query cache in a floating window
---Displays cached query results and statistics
---@module ssns.features.view_query_cache
local ViewQueryCache = {}

local UiFloat = require('ssns.ui.float')
local JsonUtils = require('ssns.utils.json')
local QueryCache = require('ssns.query_cache')

-- Store reference to current floating window for cleanup
local current_float = nil

---Close the current floating window
function ViewQueryCache.close_current_float()
  if current_float then
    if current_float.close then
      pcall(function() current_float:close() end)
    end
  end
  current_float = nil
end

---Format seconds as human readable duration
---@param seconds number
---@return string
local function format_duration(seconds)
  if seconds < 60 then
    return string.format("%ds", seconds)
  elseif seconds < 3600 then
    return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
  else
    return string.format("%dh %dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
  end
end

---View query cache
function ViewQueryCache.view_cache()
  -- Close any existing float
  ViewQueryCache.close_current_float()

  local stats = QueryCache.get_stats()
  local current_time = os.time()

  -- Build display content
  local display_lines = {}

  table.insert(display_lines, "Query Cache")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  -- Stats summary
  table.insert(display_lines, "Cache Statistics")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, string.format("  Total entries: %d", stats.total_entries))
  table.insert(display_lines, string.format("  Valid entries: %d", stats.valid_entries))
  table.insert(display_lines, string.format("  Expired entries: %d", stats.expired_entries))
  table.insert(display_lines, string.format("  Default TTL: %d seconds (%s)", QueryCache.default_ttl, format_duration(QueryCache.default_ttl)))
  table.insert(display_lines, "")

  if stats.oldest_age then
    table.insert(display_lines, string.format("  Oldest entry: %s ago", format_duration(stats.oldest_age)))
  end
  if stats.newest_age then
    table.insert(display_lines, string.format("  Newest entry: %s ago", format_duration(stats.newest_age)))
  end
  table.insert(display_lines, "")

  -- Cache entries by connection
  table.insert(display_lines, "Cache Entries")
  table.insert(display_lines, string.rep("-", 30))

  if stats.total_entries == 0 then
    table.insert(display_lines, "  (No cached queries)")
  else
    -- Group by connection
    local by_connection = {}
    for key, cached in pairs(QueryCache.cache) do
      local conn_key = key:match("^([^:]+):")
      if conn_key then
        if not by_connection[conn_key] then
          by_connection[conn_key] = {}
        end
        local query = key:sub(#conn_key + 2)
        local age = current_time - cached.timestamp
        local is_valid = age < QueryCache.default_ttl
        table.insert(by_connection[conn_key], {
          query = query,
          age = age,
          valid = is_valid,
          result_rows = cached.result and cached.result.rows and #cached.result.rows or 0,
        })
      end
    end

    -- Sort connections
    local sorted_conns = {}
    for conn in pairs(by_connection) do
      table.insert(sorted_conns, conn)
    end
    table.sort(sorted_conns)

    for _, conn in ipairs(sorted_conns) do
      local entries = by_connection[conn]
      table.insert(display_lines, "")
      table.insert(display_lines, string.format("  Connection: %s (%d queries)", conn, #entries))

      -- Sort by age (newest first)
      table.sort(entries, function(a, b) return a.age < b.age end)

      for i, entry in ipairs(entries) do
        if i > 10 then
          table.insert(display_lines, string.format("    ... and %d more", #entries - 10))
          break
        end

        local status = entry.valid and "valid" or "EXPIRED"
        local query_preview = entry.query
        if #query_preview > 50 then
          query_preview = query_preview:sub(1, 47) .. "..."
        end
        -- Clean up whitespace for display
        query_preview = query_preview:gsub("%s+", " ")

        table.insert(display_lines, string.format("    [%s] %s ago, %d rows",
          status, format_duration(entry.age), entry.result_rows))
        table.insert(display_lines, string.format("      Query: %s", query_preview))
      end
    end
  end
  table.insert(display_lines, "")

  -- JSON output
  table.insert(display_lines, "")
  table.insert(display_lines, "Statistics JSON")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  local json_lines = JsonUtils.prettify_lines(stats)
  for _, line in ipairs(json_lines) do
    table.insert(display_lines, line)
  end

  -- Create floating window
  current_float = UiFloat.create(display_lines, {
    title = "Query Cache",
    border = "rounded",
    filetype = "json",
    min_width = 60,
    max_width = 100,
    max_height = 40,
    wrap = false,
    keymaps = {
      ['r'] = function()
        ViewQueryCache.view_cache()
      end,
      ['c'] = function()
        -- Cleanup expired
        local removed = QueryCache.cleanup_expired()
        vim.notify(string.format("SSNS: Removed %d expired entries", removed), vim.log.levels.INFO)
        ViewQueryCache.view_cache()
      end,
      ['C'] = function()
        -- Clear all
        QueryCache.clear_all()
        vim.notify("SSNS: Query cache cleared", vim.log.levels.INFO)
        ViewQueryCache.view_cache()
      end,
    },
    footer = "q: close | r: refresh | c: cleanup expired | C: clear all",
  })
end

return ViewQueryCache
