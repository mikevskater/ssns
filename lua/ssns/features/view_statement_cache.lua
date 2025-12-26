---@class ViewStatementCache
---View statement cache in a floating window
---Displays the cached parse results for the current buffer
---@module ssns.features.view_statement_cache
local ViewStatementCache = {}

local BaseViewer = require('ssns.features.base_viewer')
local StatementCache = require('ssns.completion.statement_cache')

-- Create viewer instance
local viewer = BaseViewer.create({
  title = "Statement Cache",
  min_width = 60,
  max_width = 100,
  footer = "q/Esc: close | r: refresh | R: force rebuild",
})

---Close the current floating window
function ViewStatementCache.close_current_float()
  viewer:close()
end

---View statement cache for current buffer
function ViewStatementCache.view_cache()
  local info = BaseViewer.get_buffer_info()
  local bufnr = info.bufnr
  local bufname = vim.api.nvim_buf_get_name(bufnr)

  -- Get cache for current buffer
  local cache = StatementCache.get_or_build_cache(bufnr)
  local stats = StatementCache.get_stats()

  -- Set keymaps
  viewer.on_refresh = ViewStatementCache.view_cache
  viewer:set_keymaps({
    ['R'] = function()
      StatementCache.invalidate(bufnr)
      ViewStatementCache.view_cache()
    end,
  })

  -- Show with JSON output
  viewer:show_with_json(function(cb)
    BaseViewer.add_header(cb, "Statement Cache")

  -- Buffer info
  cb:section("Buffer Info")
  cb:separator("-", 30)
  cb:spans({
    { text = "  Buffer: ", style = "label" },
    { text = tostring(bufnr), style = "number" },
  })
  cb:spans({
    { text = "  File: ", style = "label" },
    { text = bufname ~= "" and vim.fn.fnamemodify(bufname, ":t") or "[No Name]", style = "value" },
  })
  cb:blank()

  if not cache then
    cb:styled("  (No cache for this buffer - not a SQL buffer?)", "muted")
    cb:blank()
  else
    -- Cache freshness
    cb:section("Cache Status")
    cb:separator("-", 30)
    local current_tick = vim.api.nvim_buf_get_changedtick(bufnr)
    local is_fresh = cache.buffer_tick == current_tick
    cb:spans({
      { text = "  Fresh: ", style = "label" },
      { text = is_fresh and "Yes" or "No (stale)", style = is_fresh and "success" or "warning" },
    })
    cb:spans({
      { text = "  Buffer tick: ", style = "label" },
      { text = tostring(cache.buffer_tick or 0), style = "number" },
      { text = " (current: " },
      { text = tostring(current_tick), style = "number" },
      { text = ")" },
    })
    cb:spans({
      { text = "  Last update: ", style = "label" },
      { text = string.format("%.3f", os.clock() - (cache.last_update or 0)), style = "number" },
      { text = " seconds ago" },
    })
    cb:blank()

    -- GO batch boundaries
    cb:section("GO Batch Boundaries")
    cb:separator("-", 30)
    if cache.go_boundaries and #cache.go_boundaries > 0 then
      cb:spans({
        { text = "  Batches: ", style = "label" },
        { text = tostring(#cache.go_boundaries + 1), style = "number" },
      })
      cb:spans({
        { text = "  GO lines: ", style = "label" },
        { text = table.concat(cache.go_boundaries, ", "), style = "keyword" },
      })
    else
      cb:styled("  Single batch (no GO statements)", "muted")
    end
    cb:blank()

    -- Temp tables
    cb:section("Temp Tables")
    cb:separator("-", 30)
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

        cb:spans({
          { text = "  " },
          { text = name, style = "warning" },
          { text = " [" },
          { text = scope, style = "muted" },
          { text = ", " },
          { text = batch, style = "muted" },
          { text = ", " },
          { text = tostring(col_count), style = "number" },
          { text = " cols]" },
          { text = dropped, style = "error" },
        })

        -- Show columns
        if info.columns and #info.columns > 0 then
          for _, col in ipairs(info.columns) do
            local col_name = col.name or col
            if type(col) == "table" then
              local src = col.source_table and (col.source_table .. ".") or ""
              cb:spans({
                { text = "    - " },
                { text = src, style = "sql_table" },
                { text = col_name, style = "sql_column" },
              })
            else
              cb:spans({
                { text = "    - " },
                { text = col_name, style = "sql_column" },
              })
            end
          end
        end
      end
    else
      cb:styled("  (No temp tables)", "muted")
    end
    cb:blank()

    -- Statement chunks summary
    cb:section("Statement Chunks")
    cb:separator("-", 30)
    if cache.chunks and #cache.chunks > 0 then
      cb:spans({
        { text = "  Total: ", style = "label" },
        { text = tostring(#cache.chunks), style = "number" },
        { text = " chunks" },
      })
      cb:blank()

      -- Count by type
      local type_counts = {}
      for _, chunk in ipairs(cache.chunks) do
        local t = chunk.statement_type or "UNKNOWN"
        type_counts[t] = (type_counts[t] or 0) + 1
      end

      cb:styled("  By type:", "label")
      local sorted_types = {}
      for t in pairs(type_counts) do
        table.insert(sorted_types, t)
      end
      table.sort(sorted_types)
      for _, t in ipairs(sorted_types) do
        cb:spans({
          { text = "    " },
          { text = t, style = "keyword" },
          { text = ": " },
          { text = tostring(type_counts[t]), style = "number" },
        })
      end
      cb:blank()

      -- List each chunk
      cb:styled("  Chunk List:", "label")
      for i, chunk in ipairs(cache.chunks) do
        local tables_count = chunk.tables and #chunk.tables or 0
        local cols_count = chunk.columns and #chunk.columns or 0
        local ctes_count = chunk.ctes and #chunk.ctes or 0

        cb:spans({
          { text = "    [" },
          { text = tostring(i), style = "number" },
          { text = "] " },
          { text = chunk.statement_type or "?", style = "keyword" },
          { text = " (L" },
          { text = tostring(chunk.start_line or 0), style = "number" },
          { text = "-" },
          { text = tostring(chunk.end_line or 0), style = "number" },
          { text = ", batch " },
          { text = tostring(chunk.go_batch_index or 0), style = "number" },
          { text = ")" },
        })
        cb:spans({
          { text = "        tables=" },
          { text = tostring(tables_count), style = "number" },
          { text = ", cols=" },
          { text = tostring(cols_count), style = "number" },
          { text = ", ctes=" },
          { text = tostring(ctes_count), style = "number" },
        })

        -- Show CTEs if any
        if chunk.ctes and #chunk.ctes > 0 then
          for _, cte in ipairs(chunk.ctes) do
            local cte_cols = cte.columns and #cte.columns or 0
            cb:spans({
              { text = "        CTE: " },
              { text = cte.name, style = "sql_view" },
              { text = " (" },
              { text = tostring(cte_cols), style = "number" },
              { text = " cols)" },
            })
          end
        end
      end
    else
      cb:styled("  (No chunks parsed)", "muted")
    end
    cb:blank()
  end

  -- Global stats
  cb:section("Global Cache Stats")
  cb:separator("-", 30)
  cb:spans({
    { text = "  Cached buffers: ", style = "label" },
    { text = tostring(stats.cached_buffers or 0), style = "number" },
  })
  cb:spans({
    { text = "  Total chunks: ", style = "label" },
    { text = tostring(stats.total_chunks or 0), style = "number" },
  })
  cb:spans({
    { text = "  Total temp tables: ", style = "label" },
    { text = tostring(stats.total_temp_tables or 0), style = "number" },
  })
  cb:spans({
    { text = "  Pending updates: ", style = "label" },
    { text = tostring(stats.pending_updates or 0), style = stats.pending_updates > 0 and "warning" or "number" },
  })
  cb:blank()

    -- Return JSON data for current buffer cache
    if cache then
      local json_cache = {
        buffer_tick = cache.buffer_tick,
        last_update = cache.last_update,
        go_boundaries = cache.go_boundaries,
        temp_tables = cache.temp_tables,
        chunks_count = cache.chunks and #cache.chunks or 0,
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

      return json_cache
    end

    return nil
  end, "Full JSON Output (Current Buffer)")
end

return ViewStatementCache

