---@class UiHistory
---Query history UI with 3-panel floating window layout using UiFloat
local UiHistory = {}

local UiFloat = require('ssns.ui.core.float')
local QueryHistory = require('ssns.query_history')
local UiQuery = require('ssns.ui.core.query')
local Cache = require('ssns.cache')
local KeymapManager = require('ssns.keymap_manager')

---@class HistoryUIState
---@field buffer_histories QueryBufferHistory[] All buffer histories
---@field selected_buffer_idx number Currently selected buffer index
---@field selected_entry_idx number Currently selected entry index

---@type MultiPanelState?
local multi_panel = nil

---@type HistoryUIState
local ui_state = {
  buffer_histories = {},
  selected_buffer_idx = 1,
  selected_entry_idx = 1,
}

---Close the history window
function UiHistory.close()
  if multi_panel then
    multi_panel:close()
    multi_panel = nil
  end
  ui_state = {
    buffer_histories = {},
    selected_buffer_idx = 1,
    selected_entry_idx = 1,
  }
end

---Render the buffer list panel
---@param state MultiPanelState
---@return string[] lines, table[] highlights
local function render_buffers(state)
  local lines = {}
  local highlights = {}
  local stats = QueryHistory.get_stats()

  -- Header
  table.insert(lines, "")
  table.insert(lines, string.format(" Total: %d buffers | %d entries", stats.total_buffers, stats.total_entries))
  table.insert(highlights, {1, 0, -1, "SsnsUiHint"})
  table.insert(lines, string.format(" Success: %d | Errors: %d", stats.success_count, stats.error_count))
  table.insert(highlights, {2, 0, -1, "SsnsUiHint"})
  table.insert(lines, "")

  for i, buffer_history in ipairs(ui_state.buffer_histories) do
    local prefix = i == ui_state.selected_buffer_idx and " ▶ " or "   "
    local entry_count = #buffer_history.entries

    local line = string.format(
      "%s%s (%s%s) - %d %s",
      prefix,
      buffer_history.buffer_name,
      buffer_history.server_name,
      buffer_history.database and ("/" .. buffer_history.database) or "",
      entry_count,
      entry_count == 1 and "entry" or "entries"
    )
    table.insert(lines, line)

    local line_idx = #lines - 1
    if i == ui_state.selected_buffer_idx then
      table.insert(highlights, {line_idx, 0, -1, "SsnsFloatSelected"})
      table.insert(highlights, {line_idx, 1, 4, "SsnsServer"})
    else
      table.insert(highlights, {line_idx, 3, 3 + #buffer_history.buffer_name, "SsnsUiHint"})
    end
  end

  if #ui_state.buffer_histories == 0 then
    table.insert(lines, "   (No history)")
    table.insert(highlights, {#lines - 1, 0, -1, "SsnsUiHint"})
  end

  return lines, highlights
end

---Render the history list panel
---@param state MultiPanelState
---@return string[] lines, table[] highlights
local function render_history(state)
  local lines = {}
  local highlights = {}

  if ui_state.selected_buffer_idx < 1 or ui_state.selected_buffer_idx > #ui_state.buffer_histories then
    table.insert(lines, "")
    table.insert(lines, " No buffer selected")
    table.insert(highlights, {1, 0, -1, "SsnsUiHint"})
    return lines, highlights
  end

  local buffer_history = ui_state.buffer_histories[ui_state.selected_buffer_idx]

  -- Header
  table.insert(lines, "")
  table.insert(lines, string.format(" %s", buffer_history.buffer_name))
  table.insert(highlights, {1, 0, -1, "SsnsUiTitle"})
  table.insert(lines, "")

  for i, entry in ipairs(buffer_history.entries) do
    local prefix = i == ui_state.selected_entry_idx and " ▶ " or "   "
    local status_icon = entry.status == "success" and "✓" or "✗"
    local query_preview = entry.query:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #query_preview > 35 then
      query_preview = query_preview:sub(1, 35) .. "..."
    end

    local line = string.format(
      "%s%s %s | %dms | %s",
      prefix,
      status_icon,
      entry.timestamp:sub(12, 19),  -- HH:MM:SS
      entry.execution_time_ms or 0,
      query_preview
    )
    table.insert(lines, line)

    local line_idx = #lines - 1
    if i == ui_state.selected_entry_idx then
      table.insert(highlights, {line_idx, 0, -1, "SsnsFloatSelected"})
    end

    -- Highlight status icon
    local hl_group = entry.status == "success" and "SsnsStatusConnected" or "SsnsStatusError"
    local icon_col = i == ui_state.selected_entry_idx and 4 or 3
    table.insert(highlights, {line_idx, icon_col, icon_col + 3, hl_group})
  end

  if #buffer_history.entries == 0 then
    table.insert(lines, "   (No entries)")
    table.insert(highlights, {#lines - 1, 0, -1, "SsnsUiHint"})
  end

  return lines, highlights
end

---Render the code preview panel
---@param state MultiPanelState
---@return string[] lines, table[] highlights
local function render_preview(state)
  local lines = {}
  local highlights = {}

  if ui_state.selected_buffer_idx < 1 or ui_state.selected_buffer_idx > #ui_state.buffer_histories then
    table.insert(lines, "-- No buffer selected")
    return lines, highlights
  end

  local buffer_history = ui_state.buffer_histories[ui_state.selected_buffer_idx]

  if ui_state.selected_entry_idx < 1 or ui_state.selected_entry_idx > #buffer_history.entries then
    table.insert(lines, "-- No entry selected")
    return lines, highlights
  end

  local entry = buffer_history.entries[ui_state.selected_entry_idx]

  -- Add metadata header as SQL comments
  table.insert(lines, string.format("-- Buffer: %s", buffer_history.buffer_name))
  table.insert(lines, string.format("-- Server: %s | Database: %s",
    buffer_history.server_name, buffer_history.database or "N/A"))
  table.insert(lines, string.format("-- Time: %s | Duration: %dms | Status: %s",
    entry.timestamp, entry.execution_time_ms or 0, entry.status))

  if entry.status == "error" then
    table.insert(lines, string.format("-- Error: %s", entry.error_message or "Unknown"))
  elseif entry.row_count then
    table.insert(lines, string.format("-- Rows: %d", entry.row_count))
  end

  table.insert(lines, "")
  table.insert(lines, "-- " .. string.rep("─", 40))
  table.insert(lines, "")

  -- Add query
  for _, query_line in ipairs(vim.split(entry.query, "\n")) do
    table.insert(lines, query_line)
  end

  -- Highlights for comment lines (first 5-7 lines)
  for i = 0, 6 do
    if lines[i + 1] and lines[i + 1]:match("^%-%-") then
      table.insert(highlights, {i, 0, -1, "Comment"})
    end
  end

  return lines, highlights
end

---Navigate in buffers panel
---@param direction number 1 for down, -1 for up
local function navigate_buffers(direction)
  if #ui_state.buffer_histories == 0 then return end

  ui_state.selected_buffer_idx = ui_state.selected_buffer_idx + direction

  -- Wrap around
  if ui_state.selected_buffer_idx < 1 then
    ui_state.selected_buffer_idx = #ui_state.buffer_histories
  elseif ui_state.selected_buffer_idx > #ui_state.buffer_histories then
    ui_state.selected_buffer_idx = 1
  end

  -- Reset entry selection
  ui_state.selected_entry_idx = 1

  -- Re-render all panels
  if multi_panel then
    multi_panel:render_all()
    multi_panel:set_cursor("buffers", ui_state.selected_buffer_idx + 4, 0)
  end
end

---Navigate in history panel
---@param direction number 1 for down, -1 for up
local function navigate_history(direction)
  local buffer_history = ui_state.buffer_histories[ui_state.selected_buffer_idx]
  if not buffer_history or #buffer_history.entries == 0 then return end

  ui_state.selected_entry_idx = ui_state.selected_entry_idx + direction

  -- Wrap around
  if ui_state.selected_entry_idx < 1 then
    ui_state.selected_entry_idx = #buffer_history.entries
  elseif ui_state.selected_entry_idx > #buffer_history.entries then
    ui_state.selected_entry_idx = 1
  end

  -- Re-render history and preview
  if multi_panel then
    multi_panel:render_panel("history")
    multi_panel:render_panel("preview")
    multi_panel:set_cursor("history", ui_state.selected_entry_idx + 3, 0)
  end
end

---Load selected query into new buffer
local function load_query()
  if ui_state.selected_buffer_idx < 1 or ui_state.selected_buffer_idx > #ui_state.buffer_histories then
    return
  end

  local buffer_history = ui_state.buffer_histories[ui_state.selected_buffer_idx]
  local entry = buffer_history.entries[ui_state.selected_entry_idx]

  if not entry then return end

  -- Look up actual ServerClass and DbClass objects from cache
  local server = Cache.find_server(buffer_history.server_name)
  local database = nil

  if server and buffer_history.database then
    database = Cache.find_database(buffer_history.server_name, buffer_history.database)
  end

  -- Close history window
  UiHistory.close()

  -- Create new query buffer
  UiQuery.create_query_buffer(server or buffer_history.server_name, database or buffer_history.database)

  -- Populate with query
  vim.schedule(function()
    local query_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_option(query_buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(query_buf, 0, -1, false, vim.split(entry.query, "\n"))

    local connection_status = ""
    if not server then
      connection_status = " (server not connected)"
    elseif not database then
      connection_status = " (database not found)"
    end

    vim.notify(
      string.format("Loaded query from %s (%s)%s", buffer_history.buffer_name, entry.timestamp, connection_status),
      vim.log.levels.INFO
    )
  end)
end

---Delete current entry or buffer
local function delete_entry()
  if ui_state.selected_buffer_idx < 1 then return end

  local buffer_history = ui_state.buffer_histories[ui_state.selected_buffer_idx]

  if multi_panel and multi_panel.focused_panel == "history" and ui_state.selected_entry_idx > 0 then
    -- Delete single entry
    table.remove(buffer_history.entries, ui_state.selected_entry_idx)

    if QueryHistory.auto_persist then
      QueryHistory.save_to_file()
    end

    -- Adjust selection
    if ui_state.selected_entry_idx > #buffer_history.entries then
      ui_state.selected_entry_idx = math.max(1, #buffer_history.entries)
    end

    vim.notify("History entry deleted", vim.log.levels.INFO)
    if multi_panel then multi_panel:render_all() end
  elseif multi_panel and multi_panel.focused_panel == "buffers" then
    -- Delete entire buffer history
    local count = #buffer_history.entries
    vim.ui.input({
      prompt = string.format("Delete buffer '%s' with %d entries? (y/N): ", buffer_history.buffer_name, count)
    }, function(input)
      if input and input:lower() == "y" then
        QueryHistory.clear_buffer_history(buffer_history.buffer_id)

        -- Refresh
        ui_state.buffer_histories = QueryHistory.get_all_buffer_histories()

        if #ui_state.buffer_histories == 0 then
          UiHistory.close()
          vim.notify("All history cleared", vim.log.levels.INFO)
        else
          if ui_state.selected_buffer_idx > #ui_state.buffer_histories then
            ui_state.selected_buffer_idx = #ui_state.buffer_histories
          end
          ui_state.selected_entry_idx = 1
          if multi_panel then multi_panel:render_all() end
        end
      end
    end)
  end
end

---Clear all history
local function clear_all()
  local stats = QueryHistory.get_stats()
  vim.ui.input({
    prompt = string.format("Clear ALL history (%d buffers, %d entries)? (y/N): ",
      stats.total_buffers, stats.total_entries)
  }, function(input)
    if input and input:lower() == "y" then
      QueryHistory.clear_all()
      UiHistory.close()
    end
  end)
end

---Export history
local function export_history()
  vim.ui.input({
    prompt = "Export to file: ",
    default = vim.fn.stdpath('data') .. '/ssns/history_export.txt',
    completion = 'file',
  }, function(filepath)
    if filepath and filepath ~= "" then
      local format = filepath:match("%.([^.]+)$") == "json" and "json" or "txt"
      if QueryHistory.export(filepath, format) then
        vim.notify("History exported to " .. filepath, vim.log.levels.INFO)
      end
    end
  end)
end

---Search history
local function search_history()
  vim.ui.input({ prompt = "Search query: " }, function(pattern)
    if not pattern or pattern == "" then return end

    local results = QueryHistory.search(pattern, { case_sensitive = false })
    if vim.tbl_isempty(results) then
      vim.notify("No matching queries found", vim.log.levels.WARN)
      return
    end

    -- Build results list
    local result_items = {}
    for buffer_id, entries in pairs(results) do
      local buffer_history = QueryHistory.buffers[buffer_id]
      if buffer_history then
        for _, entry in ipairs(entries) do
          table.insert(result_items, {
            buffer_history = buffer_history,
            entry = entry,
          })
        end
      end
    end

    -- Show results
    vim.ui.select(result_items, {
      prompt = string.format("Search results for '%s':", pattern),
      format_item = function(item)
        local status_icon = item.entry.status == "success" and "✓" or "✗"
        local preview = item.entry.query:gsub("%s+", " "):sub(1, 50)
        return string.format("%s [%s] %s | %s",
          status_icon,
          item.buffer_history.buffer_name,
          item.entry.timestamp:sub(12, 19),
          preview)
      end,
    }, function(choice)
      if choice then
        UiHistory.close()
        UiQuery.create_query_buffer(choice.buffer_history.server_name, choice.buffer_history.database)
        vim.schedule(function()
          local query_buf = vim.api.nvim_get_current_buf()
          vim.api.nvim_buf_set_option(query_buf, "modifiable", true)
          vim.api.nvim_buf_set_lines(query_buf, 0, -1, false, vim.split(choice.entry.query, "\n"))
        end)
      end
    end)
  end)
end

---Show query history in 2-column layout using UiFloat multi-panel system
---Layout: Left column (buffers on top, history on bottom) + Right column (preview full height)
---@param options table? Options {server: string?, database: string?}
function UiHistory.show_history(options)
  options = options or {}

  local buffer_histories = QueryHistory.get_all_buffer_histories()

  if #buffer_histories == 0 then
    vim.notify("No query history available", vim.log.levels.WARN)
    return
  end

  -- Apply filters
  if options.server or options.database then
    local filtered = {}
    for _, history in ipairs(buffer_histories) do
      local match = true
      if options.server and history.server_name ~= options.server then
        match = false
      end
      if options.database and history.database ~= options.database then
        match = false
      end
      if match then
        table.insert(filtered, history)
      end
    end
    buffer_histories = filtered
  end

  if #buffer_histories == 0 then
    vim.notify("No matching history entries", vim.log.levels.WARN)
    return
  end

  -- Close existing
  UiHistory.close()

  -- Initialize state
  ui_state = {
    buffer_histories = buffer_histories,
    selected_buffer_idx = 1,
    selected_entry_idx = 1,
  }

  -- Get keymaps from config
  local km = KeymapManager.get_group("history")
  local common = KeymapManager.get_group("common")

  -- Create multi-panel window using UiFloat nested layout
  -- Layout: 2 columns
  --   Left column (vertical split): Buffers on top, History on bottom
  --   Right column: Preview (full height)
  multi_panel = UiFloat.create_multi_panel({
    layout = {
      split = "horizontal",  -- Root split: left and right columns
      children = {
        {
          -- Left column: vertically stacked (buffers on top, history on bottom)
          split = "vertical",
          ratio = 0.5,
          children = {
            {
              name = "buffers",
              title = "Buffers",
              ratio = 0.4,
              on_render = render_buffers,
              on_focus = function()
                if multi_panel then
                  multi_panel:update_panel_title("buffers", "Buffers ●")
                  multi_panel:update_panel_title("history", "History")
                  -- Position cursor on selected buffer
                  multi_panel:set_cursor("buffers", ui_state.selected_buffer_idx + 4, 0)
                end
              end,
            },
            {
              name = "history",
              title = "History",
              ratio = 0.6,
              on_render = render_history,
              on_focus = function()
                if multi_panel then
                  multi_panel:update_panel_title("buffers", "Buffers")
                  multi_panel:update_panel_title("history", "History ●")
                  -- Position cursor on selected entry
                  multi_panel:set_cursor("history", ui_state.selected_entry_idx + 3, 0)
                end
              end,
            },
          },
        },
        {
          -- Right column: preview panel (full height)
          name = "preview",
          title = "Code Preview",
          ratio = 0.5,
          filetype = "sql",
          focusable = true,
          cursorline = false,
          on_render = render_preview,
        },
      },
    },
    total_width_ratio = 0.70,
    total_height_ratio = 0.70,
    footer = " <Tab>=Switch | <CR>=Load | d=Delete | c=Clear | x=Export | /=Search | q=Close ",
    initial_focus = "buffers",
    augroup_name = "SSNSQueryHistory",
    on_close = function()
      multi_panel = nil
      ui_state = {
        buffer_histories = {},
        selected_buffer_idx = 1,
        selected_entry_idx = 1,
      }
    end,
  })

  if not multi_panel then
    return
  end

  -- Render all panels
  multi_panel:render_all()

  -- Setup keymaps for buffers panel
  multi_panel:set_panel_keymaps("buffers", {
    [common.close or "q"] = function() UiHistory.close() end,
    [common.cancel or "<Esc>"] = function() UiHistory.close() end,
    [common.nav_down or "j"] = function() navigate_buffers(1) end,
    [common.nav_up or "k"] = function() navigate_buffers(-1) end,
    [common.nav_down_alt or "<Down>"] = function() navigate_buffers(1) end,
    [common.nav_up_alt or "<Up>"] = function() navigate_buffers(-1) end,
    [common.confirm or "<CR>"] = load_query,
    [common.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [common.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
    [km.delete or "d"] = delete_entry,
    [km.clear_all or "c"] = clear_all,
    [km.export or "x"] = export_history,
    [km.search or "/"] = search_history,
  })

  -- Setup keymaps for history panel
  multi_panel:set_panel_keymaps("history", {
    [common.close or "q"] = function() UiHistory.close() end,
    [common.cancel or "<Esc>"] = function() UiHistory.close() end,
    [common.nav_down or "j"] = function() navigate_history(1) end,
    [common.nav_up or "k"] = function() navigate_history(-1) end,
    [common.nav_down_alt or "<Down>"] = function() navigate_history(1) end,
    [common.nav_up_alt or "<Up>"] = function() navigate_history(-1) end,
    [common.confirm or "<CR>"] = load_query,
    [common.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [common.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
    [km.delete or "d"] = delete_entry,
    [km.clear_all or "c"] = clear_all,
    [km.export or "x"] = export_history,
    [km.search or "/"] = search_history,
  })

  -- Setup keymaps for preview panel (limited - just close and navigate)
  multi_panel:set_panel_keymaps("preview", {
    [common.close or "q"] = function() UiHistory.close() end,
    [common.cancel or "<Esc>"] = function() UiHistory.close() end,
    [common.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [common.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
  })

  -- Position cursor on first buffer (after render is complete)
  vim.schedule(function()
    if multi_panel and multi_panel:is_valid() then
      multi_panel:set_cursor("buffers", ui_state.selected_buffer_idx + 4, 0)
    end
  end)

  -- Mark focus on initial panel
  multi_panel:update_panel_title("buffers", "Buffers ●")
end

return UiHistory
