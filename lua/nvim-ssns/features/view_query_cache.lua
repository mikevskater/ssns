---@class ViewQueryCache
---View query cache in a floating window
---Displays cached query results and statistics
---@module ssns.features.view_query_cache
local ViewQueryCache = {}

local BaseViewer = require('nvim-ssns.features.base_viewer')
local QueryCache = require('nvim-ssns.query_cache')

-- Create viewer instance
local viewer = BaseViewer.create({
  title = "Query Cache",
  min_width = 60,
  max_width = 100,
  footer = "q: close | r: refresh | c: cleanup expired | C: clear all",
})

---Close the current floating window
function ViewQueryCache.close_current_float()
  viewer:close()
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
  local stats = QueryCache.get_stats()
  local current_time = os.time()

  -- Set refresh callback and custom keymaps
  viewer.on_refresh = ViewQueryCache.view_cache
  viewer:set_keymaps({
    ['c'] = function()
      local removed = QueryCache.cleanup_expired()
      vim.notify(string.format("SSNS: Removed %d expired entries", removed), vim.log.levels.INFO)
      ViewQueryCache.view_cache()
    end,
    ['C'] = function()
      QueryCache.clear_all()
      vim.notify("SSNS: Query cache cleared", vim.log.levels.INFO)
      ViewQueryCache.view_cache()
    end,
  })

  -- Show with JSON output
  viewer:show_with_json(function(cb)
    BaseViewer.add_header(cb, "Query Cache")

    -- Stats summary
    cb:section("Cache Statistics")
    cb:separator("-", 30)
    BaseViewer.add_count(cb, "Total entries", stats.total_entries)
    cb:spans({
      { text = "  Valid entries: ", style = "label" },
      { text = tostring(stats.valid_entries), style = "success" },
    })
    cb:spans({
      { text = "  Expired entries: ", style = "label" },
      { text = tostring(stats.expired_entries), style = stats.expired_entries > 0 and "warning" or "muted" },
    })
    cb:spans({
      { text = "  Default TTL: ", style = "label" },
      { text = tostring(QueryCache.default_ttl), style = "number" },
      { text = " seconds (" },
      { text = format_duration(QueryCache.default_ttl), style = "value" },
      { text = ")" },
    })
    cb:blank()

    if stats.oldest_age then
      cb:spans({
        { text = "  Oldest entry: ", style = "label" },
        { text = format_duration(stats.oldest_age), style = "muted" },
        { text = " ago" },
      })
    end
    if stats.newest_age then
      cb:spans({
        { text = "  Newest entry: ", style = "label" },
        { text = format_duration(stats.newest_age), style = "value" },
        { text = " ago" },
      })
    end
    cb:blank()

    -- Cache entries by connection
    cb:section("Cache Entries")
    cb:separator("-", 30)

    if stats.total_entries == 0 then
      cb:styled("  (No cached queries)", "muted")
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
        cb:blank()
        cb:spans({
          { text = "  Connection: ", style = "label" },
          { text = conn, style = "server" },
          { text = " (" },
          { text = tostring(#entries), style = "number" },
          { text = " queries)" },
        })

        -- Sort by age (newest first)
        table.sort(entries, function(a, b) return a.age < b.age end)

        for i, entry in ipairs(entries) do
          if i > 10 then
            cb:styled(string.format("    ... and %d more", #entries - 10), "muted")
            break
          end

          local status_style = entry.valid and "success" or "error"
          local status = entry.valid and "valid" or "EXPIRED"
          local query_preview = entry.query
          if #query_preview > 50 then
            query_preview = query_preview:sub(1, 47) .. "..."
          end
          query_preview = query_preview:gsub("%s+", " ")

          cb:spans({
            { text = "    [" },
            { text = status, style = status_style },
            { text = "] " },
            { text = format_duration(entry.age), style = "muted" },
            { text = " ago, " },
            { text = tostring(entry.result_rows), style = "number" },
            { text = " rows" },
          })
          cb:spans({
            { text = "      Query: ", style = "label" },
            { text = query_preview, style = "muted" },
          })
        end
      end
    end
    cb:blank()

    return stats
  end, "Statistics JSON")
end

return ViewQueryCache

