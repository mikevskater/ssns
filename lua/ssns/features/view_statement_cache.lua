---@class ViewStatementCache
---View statement cache in a floating window
---Displays the cached parse results for the current buffer
---@module ssns.features.view_statement_cache
local ViewStatementCache = {}

local UiFloat = require('ssns.ui.float')
local JsonUtils = require('ssns.utils.json')
local StatementCache = require('ssns.completion.statement_cache')

-- Store reference to current floating window for cleanup
local current_float = nil

---Close the current floating window
function ViewStatementCache.close_current_float()
  if current_float then
    if current_float.close then
      pcall(function() current_float:close() end)
    end
  end
  current_float = nil
end

---View statement cache for current buffer
function ViewStatementCache.view_cache()
  -- Close any existing float
  ViewStatementCache.close_current_float()

  local bufnr = vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)

  -- Get cache for current buffer
  local cache = StatementCache.get_or_build_cache(bufnr)
  local stats = StatementCache.get_stats()

  -- Build display content
  local display_lines = {}

  table.insert(display_lines, "Statement Cache")
  table.insert(display_lines, string.rep("=", 50))
  table.insert(display_lines, "")

  -- Buffer info
  table.insert(display_lines, "Buffer Info")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, string.format("  Buffer: %d", bufnr))
  table.insert(display_lines, string.format("  File: %s", bufname ~= "" and vim.fn.fnamemodify(bufname, ":t") or "[No Name]"))
  table.insert(display_lines, "")

  if not cache then
    table.insert(display_lines, "  (No cache for this buffer - not a SQL buffer?)")
    table.insert(display_lines, "")
  else
    -- Cache freshness
    table.insert(display_lines, "Cache Status")
    table.insert(display_lines, string.rep("-", 30))
    local current_tick = vim.api.nvim_buf_get_changedtick(bufnr)
    local is_fresh = cache.buffer_tick == current_tick
    table.insert(display_lines, string.format("  Fresh: %s", is_fresh and "Yes" or "No (stale)"))
    table.insert(display_lines, string.format("  Buffer tick: %d (current: %d)", cache.buffer_tick or 0, current_tick))
    table.insert(display_lines, string.format("  Last update: %.3f seconds ago", os.clock() - (cache.last_update or 0)))
    table.insert(display_lines, "")

    -- GO batch boundaries
    table.insert(display_lines, "GO Batch Boundaries")
    table.insert(display_lines, string.rep("-", 30))
    if cache.go_boundaries and #cache.go_boundaries > 0 then
      table.insert(display_lines, string.format("  Batches: %d", #cache.go_boundaries + 1))
      table.insert(display_lines, string.format("  GO lines: %s", table.concat(cache.go_boundaries, ", ")))
    else
      table.insert(display_lines, "  Single batch (no GO statements)")
    end
    table.insert(display_lines, "")

    -- Temp tables
    table.insert(display_lines, "Temp Tables")
    table.insert(display_lines, string.rep("-", 30))
    if cache.temp_tables and next(cache.temp_tables) then
      local sorted_temps = {}
      for name in pairs(cache.temp_tables) do
        table.insert(sorted_temps, name)
      end
      table.sort(sorted_temps)

      for _, name in ipairs(sorted_temps) do
        local info = cache.temp_tables[name]
        local scope = info.is_global and "##global" or "#local"
        local batch = string.format("batch %d", info.created_in_batch or 0)
        local col_count = info.columns and #info.columns or 0
        local dropped = info.dropped_at_line and string.format(" (dropped L%d)", info.dropped_at_line) or ""

        table.insert(display_lines, string.format("  %s [%s, %s, %d cols]%s",
          name, scope, batch, col_count, dropped))

        -- Show columns
        if info.columns and #info.columns > 0 then
          for _, col in ipairs(info.columns) do
            local col_name = col.name or col
            if type(col) == "table" then
              local src = col.source_table and (col.source_table .. ".") or ""
              table.insert(display_lines, string.format("    - %s%s", src, col_name))
            else
              table.insert(display_lines, string.format("    - %s", col_name))
            end
          end
        end
      end
    else
      table.insert(display_lines, "  (No temp tables)")
    end
    table.insert(display_lines, "")

    -- Statement chunks summary
    table.insert(display_lines, "Statement Chunks")
    table.insert(display_lines, string.rep("-", 30))
    if cache.chunks and #cache.chunks > 0 then
      table.insert(display_lines, string.format("  Total: %d chunks", #cache.chunks))
      table.insert(display_lines, "")

      -- Count by type
      local type_counts = {}
      for _, chunk in ipairs(cache.chunks) do
        local t = chunk.statement_type or "UNKNOWN"
        type_counts[t] = (type_counts[t] or 0) + 1
      end

      table.insert(display_lines, "  By type:")
      local sorted_types = {}
      for t in pairs(type_counts) do
        table.insert(sorted_types, t)
      end
      table.sort(sorted_types)
      for _, t in ipairs(sorted_types) do
        table.insert(display_lines, string.format("    %s: %d", t, type_counts[t]))
      end
      table.insert(display_lines, "")

      -- List each chunk
      table.insert(display_lines, "  Chunk List:")
      for i, chunk in ipairs(cache.chunks) do
        local tables_count = chunk.tables and #chunk.tables or 0
        local cols_count = chunk.columns and #chunk.columns or 0
        local ctes_count = chunk.ctes and #chunk.ctes or 0

        table.insert(display_lines, string.format("    [%d] %s (L%d-%d, batch %d)",
          i,
          chunk.statement_type or "?",
          chunk.start_line or 0,
          chunk.end_line or 0,
          chunk.go_batch_index or 0))
        table.insert(display_lines, string.format("        tables=%d, cols=%d, ctes=%d",
          tables_count, cols_count, ctes_count))

        -- Show CTEs if any
        if chunk.ctes and #chunk.ctes > 0 then
          for _, cte in ipairs(chunk.ctes) do
            local cte_cols = cte.columns and #cte.columns or 0
            table.insert(display_lines, string.format("        CTE: %s (%d cols)", cte.name, cte_cols))
          end
        end
      end
    else
      table.insert(display_lines, "  (No chunks parsed)")
    end
    table.insert(display_lines, "")
  end

  -- Global stats
  table.insert(display_lines, "Global Cache Stats")
  table.insert(display_lines, string.rep("-", 30))
  table.insert(display_lines, string.format("  Cached buffers: %d", stats.cached_buffers or 0))
  table.insert(display_lines, string.format("  Total chunks: %d", stats.total_chunks or 0))
  table.insert(display_lines, string.format("  Total temp tables: %d", stats.total_temp_tables or 0))
  table.insert(display_lines, string.format("  Pending updates: %d", stats.pending_updates or 0))
  table.insert(display_lines, "")

  -- JSON output for current buffer cache
  if cache then
    table.insert(display_lines, "")
    table.insert(display_lines, "Full JSON Output (Current Buffer)")
    table.insert(display_lines, string.rep("=", 50))
    table.insert(display_lines, "")

    -- Create a cleaned version for JSON (limit chunk details)
    local json_cache = {
      buffer_tick = cache.buffer_tick,
      last_update = cache.last_update,
      go_boundaries = cache.go_boundaries,
      temp_tables = cache.temp_tables,
      chunks_count = cache.chunks and #cache.chunks or 0,
      -- Include first 5 chunks for reference
      chunks_preview = {},
    }

    if cache.chunks then
      for i = 1, math.min(5, #cache.chunks) do
        local chunk = cache.chunks[i]
        table.insert(json_cache.chunks_preview, {
          statement_type = chunk.statement_type,
          start_line = chunk.start_line,
          end_line = chunk.end_line,
          go_batch_index = chunk.go_batch_index,
          tables_count = chunk.tables and #chunk.tables or 0,
          columns_count = chunk.columns and #chunk.columns or 0,
          ctes_count = chunk.ctes and #chunk.ctes or 0,
        })
      end
    end

    local json_lines = JsonUtils.prettify_lines(json_cache)
    for _, line in ipairs(json_lines) do
      table.insert(display_lines, line)
    end
  end

  -- Create floating window
  current_float = UiFloat.create(display_lines, {
    title = "Statement Cache",
    border = "rounded",
    filetype = "json",
    min_width = 60,
    max_width = 100,
    max_height = 45,
    wrap = false,
    keymaps = {
      ['r'] = function()
        -- Refresh: rebuild cache and update display
        ViewStatementCache.view_cache()
      end,
      ['R'] = function()
        -- Force rebuild: invalidate and rebuild
        StatementCache.invalidate(bufnr)
        ViewStatementCache.view_cache()
      end,
    },
    footer = "q/Esc: close | r: refresh | R: force rebuild",
  })
end

return ViewStatementCache
