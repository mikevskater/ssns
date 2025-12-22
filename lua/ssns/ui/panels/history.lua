---@class UiHistory
---Query history UI with 3-panel floating window layout using UiFloat
local UiHistory = {}

local UiFloat = require('ssns.ui.core.float')
local QueryHistory = require('ssns.query_history')
local UiQuery = require('ssns.ui.core.query')
local Cache = require('ssns.cache')
local KeymapManager = require('ssns.keymap_manager')
local Spinner = require('ssns.async.spinner')
local Cancellation = require('ssns.async.cancellation')
local Thread = require('ssns.async.thread')

---@class HistoryMatchPosition
---@field start number 1-indexed start position
---@field end_ number 1-indexed end position
---@field text string The matched text fragment

---@class HistoryEntryMatch
---@field buffer_idx number Index into all_buffer_histories
---@field entry_idx number Index into buffer entries
---@field positions HistoryMatchPosition[] Match positions in the query

---@class HistoryUIState
---@field all_buffer_histories QueryBufferHistory[] Unfiltered buffer histories
---@field buffer_histories QueryBufferHistory[] Filtered buffer histories (for display)
---@field entry_matches table<string, HistoryMatchPosition[]> Map of "buffer_idx:entry_idx" to match positions
---@field selected_buffer_idx number Currently selected buffer index
---@field selected_entry_idx number Currently selected entry index
---@field search_term string Committed search term
---@field search_term_before_edit string Search term before current edit (for ESC revert)
---@field search_editing boolean Whether user is currently editing search
---@field search_case_sensitive boolean Case sensitive search
---@field search_use_regex boolean Use regex for search (vs literal)
---@field search_whole_word boolean Match whole words only
---@field search_in_progress boolean Whether async search is running
---@field search_progress number Search progress 0-100
---@field search_cancel_token CancellationToken? Token to cancel current search

---@type MultiPanelState?
local multi_panel = nil

---@type number?
local search_augroup = nil

---Namespace for search virtual text
local search_virt_ns = vim.api.nvim_create_namespace("ssns_search_virt")

---@type Spinner?
local search_spinner = nil

---@type HistoryUIState
local ui_state = {
  all_buffer_histories = {},
  buffer_histories = {},
  entry_matches = {},
  selected_buffer_idx = 1,
  selected_entry_idx = 1,
  search_term = "",
  search_term_before_edit = "",
  search_editing = false,
  search_case_sensitive = false,
  search_use_regex = true,
  search_whole_word = false,
  search_in_progress = false,
  search_progress = 0,
  search_cancel_token = nil,
}

---Close the history window
function UiHistory.close()
  -- Clean up search autocmds
  if search_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, search_augroup)
    search_augroup = nil
  end

  -- Cancel any in-progress search
  if ui_state.search_cancel_token then
    ui_state.search_cancel_token:cancel()
    ui_state.search_cancel_token = nil
  end

  -- Cancel search thread
  if search_thread_id then
    Thread.cancel(search_thread_id, "Panel closed")
    search_thread_id = nil
  end

  -- Stop search spinner
  if search_spinner then
    search_spinner:stop()
    search_spinner = nil
  end

  if multi_panel then
    multi_panel:close()
    multi_panel = nil
  end

  ui_state = {
    all_buffer_histories = {},
    buffer_histories = {},
    entry_matches = {},
    selected_buffer_idx = 1,
    selected_entry_idx = 1,
    search_term = "",
    search_term_before_edit = "",
    search_editing = false,
    search_case_sensitive = false,
    search_use_regex = true,
    search_whole_word = false,
    search_in_progress = false,
    search_progress = 0,
    search_cancel_token = nil,
  }
end

---Get the current spinner frame for search progress display
---@return string spinner_char
local function get_search_spinner_frame()
  if search_spinner then
    return search_spinner:get_frame()
  end
  return ""
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

  -- Show search progress if searching
  if ui_state.search_in_progress then
    local spinner_char = get_search_spinner_frame()
    if spinner_char == "" then spinner_char = "⠋" end

    table.insert(lines, "")
    table.insert(lines, string.format(" %s Searching... %d%%", spinner_char, ui_state.search_progress))
    table.insert(highlights, {1, 0, -1, "SsnsUiHint"})

    if #ui_state.buffer_histories > 0 then
      table.insert(lines, string.format(" %d matches so far", #ui_state.buffer_histories))
      table.insert(highlights, {2, 0, -1, "SsnsStatusConnected"})
    end
    table.insert(lines, "")
  end

  if ui_state.selected_buffer_idx < 1 or ui_state.selected_buffer_idx > #ui_state.buffer_histories then
    if not ui_state.search_in_progress then
      table.insert(lines, "")
      table.insert(lines, " No buffer selected")
      table.insert(highlights, {1, 0, -1, "SsnsUiHint"})
    end
    return lines, highlights
  end

  local buffer_history = ui_state.buffer_histories[ui_state.selected_buffer_idx]

  -- Find the original buffer index in all_buffer_histories for match lookup
  local orig_buf_idx = nil
  for idx, bh in ipairs(ui_state.all_buffer_histories) do
    if bh == buffer_history then
      orig_buf_idx = idx
      break
    end
  end

  -- Header
  if not ui_state.search_in_progress then
    table.insert(lines, "")
  end
  table.insert(lines, string.format(" %s", buffer_history.buffer_name))
  table.insert(highlights, {#lines - 1, 0, -1, "SsnsUiTitle"})
  table.insert(lines, "")

  for i, entry in ipairs(buffer_history.entries) do
    local prefix = i == ui_state.selected_entry_idx and " ▶ " or "   "

    -- Determine icon based on source and status:
    -- - Auto-save entries: [A]
    -- - Executed success: ✓
    -- - Executed error: ✗
    local status_icon, icon_hl, icon_len
    if entry.source == "auto_save" then
      status_icon = "[A]"
      icon_hl = "SsnsUiHint"
      icon_len = 3
    elseif entry.status == "success" then
      status_icon = "✓"
      icon_hl = "SsnsStatusConnected"
      icon_len = 3  -- UTF-8 checkmark is 3 bytes
    else
      status_icon = "✗"
      icon_hl = "SsnsStatusError"
      icon_len = 3  -- UTF-8 cross is 3 bytes
    end

    -- Get first line of query (no normalization - display exactly as saved)
    local first_newline = entry.query:find("\n")
    local query_preview = first_newline and entry.query:sub(1, first_newline - 1) or entry.query
    local was_truncated = false
    if #query_preview > 50 then
      query_preview = query_preview:sub(1, 50)
      was_truncated = true
    end

    -- Build the metadata prefix
    local meta_prefix = string.format(
      "%s%s %s | %dms | ",
      prefix,
      status_icon,
      entry.timestamp:sub(12, 19),  -- HH:MM:SS
      entry.execution_time_ms or 0
    )

    local line = meta_prefix .. query_preview .. (was_truncated and "..." or "")
    table.insert(lines, line)

    local line_idx = #lines - 1
    if i == ui_state.selected_entry_idx then
      table.insert(highlights, {line_idx, 0, -1, "SsnsFloatSelected"})
    end

    -- Highlight status icon
    local icon_col = i == ui_state.selected_entry_idx and 4 or 3
    table.insert(highlights, {line_idx, icon_col, icon_col + icon_len, icon_hl})

    -- Highlight search matches in query_preview (skip if selected row)
    if orig_buf_idx and i ~= ui_state.selected_entry_idx then
      local match_key = string.format("%d:%d", orig_buf_idx, i)
      local positions = ui_state.entry_matches[match_key]
      if positions and #positions > 0 then
        local query_start_col = #meta_prefix
        for _, pos in ipairs(positions) do
          -- Only highlight if position is within the visible preview
          if pos.start <= #query_preview then
            local col_start = query_start_col + pos.start - 1
            local col_end = query_start_col + math.min(pos.end_, #query_preview)
            table.insert(highlights, {line_idx, col_start, col_end, "SsnsSearchMatch"})
          end
        end
      end
    end
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

  -- Show different info based on source type
  if entry.source == "auto_save" then
    table.insert(lines, string.format("-- Time: %s | Type: Auto-Save", entry.timestamp))
  else
    table.insert(lines, string.format("-- Time: %s | Duration: %dms | Status: %s",
      entry.timestamp, entry.execution_time_ms or 0, entry.status))

    if entry.status == "error" then
      table.insert(lines, string.format("-- Error: %s", entry.error_message or "Unknown"))
    elseif entry.row_count then
      table.insert(lines, string.format("-- Rows: %d", entry.row_count))
    end
  end

  table.insert(lines, "")
  table.insert(lines, "-- " .. string.rep("─", 40))
  table.insert(lines, "")

  -- Track where query content starts (for match position offsets)
  local query_start_line = #lines

  -- Add query lines
  local query_lines = vim.split(entry.query, "\n")
  for _, query_line in ipairs(query_lines) do
    table.insert(lines, query_line)
  end

  -- Highlights for comment lines (first 5-7 lines)
  for i = 0, 6 do
    if lines[i + 1] and lines[i + 1]:match("^%-%-") then
      table.insert(highlights, {i, 0, -1, "Comment"})
    end
  end

  -- Get match positions for overlay highlighting
  local orig_buf_idx = nil
  for idx, bh in ipairs(ui_state.all_buffer_histories) do
    if bh == buffer_history then
      orig_buf_idx = idx
      break
    end
  end

  if orig_buf_idx then
    local match_key = string.format("%d:%d", orig_buf_idx, ui_state.selected_entry_idx)
    local positions = ui_state.entry_matches[match_key]

    if positions and #positions > 0 then
      -- Track character position in the full query text
      local current_pos = 1

      for line_idx, query_line in ipairs(query_lines) do
        local line_start = current_pos
        local line_end = current_pos + #query_line - 1
        local display_line_idx = query_start_line + line_idx - 1  -- 0-indexed

        -- Find positions overlapping this line
        for _, pos in ipairs(positions) do
          if pos.end_ >= line_start and pos.start <= line_end then
            -- Calculate column positions (0-indexed for nvim API)
            local col_start = math.max(0, pos.start - line_start)
            local col_end = math.min(#query_line, pos.end_ - line_start + 1)
            table.insert(highlights, {display_line_idx, col_start, col_end, "SsnsSearchMatch"})
          end
        end

        -- Move position past this line plus newline character
        current_pos = line_end + 2
      end
    end
  end

  return lines, highlights
end

---Build the search settings hint line
---@return string line, table[] highlights (relative to this line)
local function build_search_settings_line()
  local case_state = ui_state.search_case_sensitive and "On" or "Off"
  local regex_state = ui_state.search_use_regex and "On" or "Off"
  local word_state = ui_state.search_whole_word and "On" or "Off"

  -- Format: " A-c Case:Off | A-r Regex:On | A-w Word:Off"
  local line = string.format(" A-c Case:%s | A-r Regex:%s | A-w Word:%s", case_state, regex_state, word_state)

  -- Simple highlight - just highlight the whole line as Comment
  -- States will be highlighted based on their value
  local highlights = {}
  table.insert(highlights, {0, 0, #line, "Comment"})

  return line, highlights
end

---Render the search panel
---@param state MultiPanelState
---@return string[] lines, table[] highlights
local function render_search(state)
  local lines = {}
  local highlights = {}

  if ui_state.search_editing then
    -- Don't render while editing - buffer content is live
    -- Settings line will be shown via virtual text in activate_search
    return {""}, {}
  end

  -- Line 1: Search term or placeholder
  if ui_state.search_term == "" then
    table.insert(lines, " Press / to search")
    table.insert(highlights, {0, 0, -1, "Comment"})
  else
    table.insert(lines, " " .. ui_state.search_term)
    table.insert(highlights, {0, 0, -1, "SsnsUiHint"})
  end

  -- Line 2: Settings hints
  local settings_line, settings_hl = build_search_settings_line()
  table.insert(lines, settings_line)
  -- Adjust highlight line numbers for line 2
  for _, hl in ipairs(settings_hl) do
    hl[1] = 1  -- Line index 1 (second line)
    table.insert(highlights, hl)
  end

  return lines, highlights
end

---@type string? Current search thread task ID
local search_thread_id = nil

---Apply search filter to buffer histories (threaded async)
---@param pattern string Search pattern (regex or plain text)
local function apply_search_filter(pattern)
  -- Cancel any existing search
  if ui_state.search_cancel_token then
    ui_state.search_cancel_token:cancel()
    ui_state.search_cancel_token = nil
  end

  -- Stop existing thread
  if search_thread_id then
    Thread.cancel(search_thread_id, "New search started")
    search_thread_id = nil
  end

  -- Stop existing spinner
  if search_spinner then
    search_spinner:stop()
    search_spinner = nil
  end

  -- Clear previous matches
  ui_state.entry_matches = {}

  if not pattern or pattern == "" then
    ui_state.buffer_histories = ui_state.all_buffer_histories
    ui_state.search_in_progress = false
    ui_state.search_progress = 0
    if multi_panel then
      multi_panel:render_all()
    end
    return
  end

  -- Flatten all entries for the worker
  local worker_entries = {}
  for buf_idx, buffer_history in ipairs(ui_state.all_buffer_histories) do
    for entry_idx, entry in ipairs(buffer_history.entries) do
      table.insert(worker_entries, {
        buf_idx = buf_idx,
        entry_idx = entry_idx,
        query = entry.query,
      })
    end
  end

  if #worker_entries == 0 then
    ui_state.buffer_histories = {}
    ui_state.search_in_progress = false
    if multi_panel then
      multi_panel:render_all()
    end
    return
  end

  -- Set up search state
  ui_state.search_in_progress = true
  ui_state.search_progress = 0
  ui_state.search_cancel_token = Cancellation.create_token()

  -- Track matching buffers
  local matching_buffers = {}
  local seen_buffers = {}

  -- Start spinner
  search_spinner = Spinner.create_text_spinner({
    on_tick = function()
      if multi_panel then
        multi_panel:render_all()
      end
    end,
  })
  search_spinner:start()

  -- Start threaded search
  local task_id, err = Thread.start({
    worker = "history_search",
    input = {
      entries = worker_entries,
      pattern = pattern,
      options = {
        case_sensitive = ui_state.search_case_sensitive,
        use_regex = ui_state.search_use_regex,
        whole_word = ui_state.search_whole_word,
        batch_interval_ms = 100,
      },
    },
    on_batch = function(batch)
      if ui_state.search_cancel_token and ui_state.search_cancel_token.is_cancelled then
        return
      end
      -- Process batch of matches
      for _, item in ipairs(batch.items or {}) do
        local key = string.format("%d:%d", item.buf_idx, item.entry_idx)
        ui_state.entry_matches[key] = item.positions

        -- Track matching buffer
        if not seen_buffers[item.buf_idx] then
          seen_buffers[item.buf_idx] = true
          local buffer_history = ui_state.all_buffer_histories[item.buf_idx]
          if buffer_history then
            table.insert(matching_buffers, buffer_history)
          end
        end
      end

      -- Update filtered results
      ui_state.buffer_histories = matching_buffers
      ui_state.search_progress = batch.progress or 0

      -- Reset selection if needed
      if ui_state.selected_buffer_idx > #ui_state.buffer_histories then
        ui_state.selected_buffer_idx = math.max(1, #ui_state.buffer_histories)
      end
      ui_state.selected_entry_idx = 1

      if multi_panel then
        multi_panel:render_all()
      end
    end,
    on_progress = function(pct, message)
      ui_state.search_progress = pct or 0
      if multi_panel then
        multi_panel:render_all()
      end
    end,
    on_complete = function(result, error_msg)
      search_thread_id = nil

      if error_msg then
        vim.notify(string.format("[SSNS] History search error: %s", error_msg), vim.log.levels.ERROR)
      end

      if result and result.cancelled then
        ui_state.search_progress = 0
      end

      -- Search complete
      ui_state.search_in_progress = false
      ui_state.search_cancel_token = nil

      if search_spinner then
        search_spinner:stop()
        search_spinner = nil
      end

      if multi_panel then
        multi_panel:render_all()
      end
    end,
    timeout_ms = 30000,
  })

  if not task_id then
    -- Thread failed to start
    vim.notify(string.format("[SSNS] Failed to start history search: %s", err or "unknown"), vim.log.levels.ERROR)
    ui_state.search_in_progress = false
    ui_state.search_cancel_token = nil
    if search_spinner then
      search_spinner:stop()
      search_spinner = nil
    end
    if multi_panel then
      multi_panel:render_all()
    end
    return
  end

  search_thread_id = task_id
end

---Finalize search exit (called after insert mode exits)
local function finalize_search_exit()
  ui_state.search_editing = false

  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
    -- Clear virtual text
    vim.api.nvim_buf_clear_namespace(search_buf, search_virt_ns, 0, -1)
    vim.api.nvim_buf_set_option(search_buf, 'modifiable', false)
  end

  -- Clean up autocmds
  if search_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, search_augroup)
    search_augroup = nil
  end

  -- Re-render all panels to show committed state
  if multi_panel then
    multi_panel:render_panel("search")
    multi_panel:render_panel("buffers")
    multi_panel:render_panel("history")
    multi_panel:render_panel("preview")
  end

  -- Return focus to buffers panel (scheduled to ensure it happens after mode change completes)
  vim.schedule(function()
    if multi_panel and multi_panel:is_valid() then
      multi_panel:focus_panel("buffers")
    end
  end)
end

---Cancel search and revert to previous state
local function cancel_search()
  ui_state.search_term = ui_state.search_term_before_edit
  -- Apply the previous search (or clear if empty)
  if multi_panel then
    apply_search_filter(ui_state.search_term)
  end
  vim.cmd('stopinsert')
end

---Commit current search text and apply the filter
local function commit_search()
  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if search_buf and vim.api.nvim_buf_is_valid(search_buf) then
    local lines = vim.api.nvim_buf_get_lines(search_buf, 0, 1, false)
    ui_state.search_term = (lines[1] or ""):gsub("^%s+", "")  -- Trim leading space
  end
  -- Apply the search filter
  if multi_panel then
    apply_search_filter(ui_state.search_term)
  end
  vim.cmd('stopinsert')
end

---Update the virtual text settings line in search buffer during editing
local function update_search_settings_virt_text()
  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if not search_buf or not vim.api.nvim_buf_is_valid(search_buf) then return end

  -- Clear existing virtual text
  vim.api.nvim_buf_clear_namespace(search_buf, search_virt_ns, 0, -1)

  -- Build the settings line
  local settings_line, _ = build_search_settings_line()

  -- Add as virtual line below line 0
  vim.api.nvim_buf_set_extmark(search_buf, search_virt_ns, 0, 0, {
    virt_lines = {{
      {settings_line, "Comment"},
    }},
    virt_lines_above = false,
  })
end

---Toggle case sensitivity (will apply on next commit)
local function toggle_case_sensitive()
  ui_state.search_case_sensitive = not ui_state.search_case_sensitive

  -- Update virtual text to show new state
  update_search_settings_virt_text()

  -- Re-render search panel to show updated state
  if multi_panel then
    multi_panel:render_panel("search")
  end
end

---Toggle regex mode (will apply on next commit)
local function toggle_regex_mode()
  ui_state.search_use_regex = not ui_state.search_use_regex

  -- Update virtual text to show new state
  update_search_settings_virt_text()

  -- Re-render search panel to show updated state
  if multi_panel then
    multi_panel:render_panel("search")
  end
end

---Toggle whole word mode (will apply on next commit)
local function toggle_whole_word()
  ui_state.search_whole_word = not ui_state.search_whole_word

  -- Update virtual text to show new state
  update_search_settings_virt_text()

  -- Re-render search panel to show updated state
  if multi_panel then
    multi_panel:render_panel("search")
  end
end

---Setup autocmds for search mode
local function setup_search_autocmds()
  local search_buf = multi_panel and multi_panel:get_panel_buffer("search")
  if not search_buf then return end

  -- Clean up existing autocmds
  if search_augroup then
    pcall(vim.api.nvim_del_augroup_by_id, search_augroup)
  end

  search_augroup = vim.api.nvim_create_augroup("SSNSHistorySearch", { clear = true })

  -- Handle insert mode exit (search is applied on <CR>/<Tab>, cancelled on <Esc>)
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = search_augroup,
    buffer = search_buf,
    once = true,
    callback = function()
      -- This fires after ESC/TAB/CR keymap handlers
      finalize_search_exit()
    end,
  })

  -- Setup insert mode keymaps using KeymapManager to handle conflicts
  KeymapManager.set(search_buf, 'i', '<Esc>', function()
    cancel_search()
  end, { nowait = true })

  KeymapManager.set(search_buf, 'i', '<Tab>', function()
    commit_search()
  end, { nowait = true })

  KeymapManager.set(search_buf, 'i', '<CR>', function()
    commit_search()
  end, { nowait = true })

  -- Toggle search settings keymaps (using Alt keys to avoid conflicts)
  KeymapManager.set(search_buf, 'i', '<A-c>', function()
    toggle_case_sensitive()
  end, { nowait = true })

  KeymapManager.set(search_buf, 'i', '<A-r>', function()
    toggle_regex_mode()
  end, { nowait = true })

  KeymapManager.set(search_buf, 'i', '<A-w>', function()
    toggle_whole_word()
  end, { nowait = true })

  -- Setup auto-restore for keymaps
  KeymapManager.setup_auto_restore(search_buf)
end

---Activate search mode
local function activate_search()
  if not multi_panel then return end

  -- Capture current state for ESC revert
  ui_state.search_term_before_edit = ui_state.search_term
  ui_state.search_editing = true

  local search_buf = multi_panel:get_panel_buffer("search")
  if not search_buf then return end

  -- Make buffer modifiable
  vim.api.nvim_buf_set_option(search_buf, 'modifiable', true)

  -- Disable autocompletion in search buffer
  vim.b[search_buf].cmp_enabled = false      -- nvim-cmp
  vim.b[search_buf].blink_cmp_enable = false -- blink.cmp
  vim.b[search_buf].completion = false       -- generic

  -- Set content: existing search term or empty (with leading space for padding)
  local initial_text = ui_state.search_term ~= "" and (" " .. ui_state.search_term) or " "
  vim.api.nvim_buf_set_lines(search_buf, 0, -1, false, {initial_text})

  -- Focus search window and enter insert mode at end
  local search_win = multi_panel:get_panel_window("search")
  if search_win and vim.api.nvim_win_is_valid(search_win) then
    vim.api.nvim_set_current_win(search_win)
    vim.api.nvim_win_set_cursor(search_win, {1, #initial_text})
    vim.cmd('startinsert!')
  end

  -- Setup autocmds for live filtering and exit handling
  setup_search_autocmds()

  -- Show settings line as virtual text during editing
  update_search_settings_virt_text()
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

  -- DON'T re-render history panel on navigation - just move cursor
  -- This avoids expensive re-renders on every j/k press
  if multi_panel then
    multi_panel:set_cursor("history", ui_state.selected_entry_idx + 3, 0)
    -- Only re-render preview panel (shows selected entry content)
    multi_panel:render_panel("preview")
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

  -- Capture buffer_id before closing (to continue history)
  local history_buffer_id = buffer_history.buffer_id

  -- Close history window
  UiHistory.close()

  -- Create new query buffer with original history buffer_id to continue the same history
  UiQuery.create_query_buffer(
    server or buffer_history.server_name,
    database or buffer_history.database,
    nil,  -- sql (we'll set it below)
    nil,  -- object_name
    history_buffer_id  -- Continue this history
  )

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
    -- Delete entire buffer history - show confirmation dialog
    local count = #buffer_history.entries
    local confirm_win = UiFloat.create({
      title = "Delete Buffer History",
      width = 50,
      height = 8,
      center = true,
      content_builder = true,
      zindex = UiFloat.ZINDEX.MODAL,
    })

    if confirm_win then
      local cb = confirm_win:get_content_builder()
      cb:line("")
      cb:line(string.format("  Delete buffer '%s'?", buffer_history.buffer_name), "WarningMsg")
      cb:line(string.format("  Contains %d history entries.", count), "SsnsUiHint")
      cb:line("")
      cb:line("  Press <Enter> to confirm, <Esc> to cancel", "Comment")
      confirm_win:render()

      local confirm_keymaps = {
        ["<CR>"] = function()
          confirm_win:close()
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
            vim.notify("Buffer history deleted", vim.log.levels.INFO)
          end
        end,
        ["<Esc>"] = function() confirm_win:close() end,
        ["q"] = function() confirm_win:close() end,
        ["n"] = function() confirm_win:close() end,
      }
      for key, fn in pairs(confirm_keymaps) do
        vim.keymap.set("n", key, fn, { buffer = confirm_win.buf, nowait = true })
      end
    end
  end
end

---Clear all history
local function clear_all()
  local stats = QueryHistory.get_stats()
  local confirm_win = UiFloat.create({
    title = "Clear All History",
    width = 55,
    height = 8,
    center = true,
    content_builder = true,
    zindex = UiFloat.ZINDEX.MODAL,
  })

  if confirm_win then
    local cb = confirm_win:get_content_builder()
    cb:line("")
    cb:line("  ⚠ Clear ALL query history?", "WarningMsg")
    cb:line(string.format("  %d buffers, %d entries will be deleted.", stats.total_buffers, stats.total_entries), "SsnsUiHint")
    cb:line("")
    cb:line("  Press <Enter> to confirm, <Esc> to cancel", "Comment")
    confirm_win:render()

    local confirm_keymaps = {
      ["<CR>"] = function()
        confirm_win:close()
        QueryHistory.clear_all()
        UiHistory.close()
        vim.notify("All history cleared", vim.log.levels.INFO)
      end,
      ["<Esc>"] = function() confirm_win:close() end,
      ["q"] = function() confirm_win:close() end,
      ["n"] = function() confirm_win:close() end,
    }
    for key, fn in pairs(confirm_keymaps) do
      vim.keymap.set("n", key, fn, { buffer = confirm_win.buf, nowait = true })
    end
  end
end

---Export history
local function export_history()
  local default_path = vim.fn.stdpath('data') .. '/ssns/history_export.txt'

  local export_win = UiFloat.create({
    title = "Export History",
    width = 70,
    height = 9,
    center = true,
    content_builder = true,
    enable_inputs = true,
    zindex = UiFloat.ZINDEX.MODAL,
  })

  if export_win then
    local cb = export_win:get_content_builder()
    cb:line("")
    cb:line("  Export query history to file:", "SsnsUiTitle")
    cb:line("")
    cb:labeled_input("filepath", "  File", {
      value = default_path,
      placeholder = "(enter path)",
      width = 50,  -- Default width, expands for longer paths
    })
    cb:line("")
    cb:line("  Use .json extension for JSON format, otherwise plain text.", "Comment")
    cb:line("")
    cb:line("  <Enter>=Export | <Esc>=Cancel", "SsnsUiHint")
    export_win:render()

    local function do_export()
      local filepath = export_win:get_input_value("filepath")
      export_win:close()

      if filepath and filepath ~= "" then
        local format = filepath:match("%.([^.]+)$") == "json" and "json" or "txt"
        if QueryHistory.export(filepath, format) then
          vim.notify("History exported to " .. filepath, vim.log.levels.INFO)
        end
      end
    end

    vim.keymap.set("n", "<CR>", function()
      export_win:enter_input()
    end, { buffer = export_win.buf, nowait = true })

    vim.keymap.set("n", "<Esc>", function()
      export_win:close()
    end, { buffer = export_win.buf, nowait = true })

    vim.keymap.set("n", "q", function()
      export_win:close()
    end, { buffer = export_win.buf, nowait = true })

    -- Submit binding when in input mode
    export_win:on_input_submit(do_export)
  end
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
    all_buffer_histories = buffer_histories,
    buffer_histories = buffer_histories,  -- Initially unfiltered
    entry_matches = {},
    selected_buffer_idx = 1,
    selected_entry_idx = 1,
    search_term = "",
    search_term_before_edit = "",
    search_editing = false,
    search_case_sensitive = false,
    search_use_regex = true,
    search_whole_word = false,
    search_in_progress = false,
    search_progress = 0,
    search_cancel_token = nil,
  }

  -- Get keymaps from config
  local km = KeymapManager.get_group("history")
  local common = KeymapManager.get_group("common")

  -- Create multi-panel window using UiFloat nested layout
  -- Layout: 2 columns
  --   Left column (vertical split): Search on top, Buffers in middle, History on bottom
  --   Right column: Preview (full height)
  multi_panel = UiFloat.create_multi_panel({
    layout = {
      split = "horizontal",  -- Root split: left and right columns
      children = {
        {
          -- Left column: vertically stacked (search, buffers, history)
          split = "vertical",
          ratio = 0.5,
          children = {
            {
              name = "search",
              title = "Search",
              ratio = 0.01,
              min_height = 2,  -- Ensure search + settings line always visible
              focusable = false,  -- NOT in TAB cycle
              cursorline = false,
              on_render = render_search,
            },
            {
              name = "buffers",
              title = "Buffers",
              ratio = 0.55,  -- Taller buffers list
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
              ratio = 0.44,  -- Shorter history list
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
          -- Skip full semantic highlighting (which connects to DB and loads objects)
          -- Use basic tokenization-based highlighting instead
          -- on_pre_filetype runs BEFORE filetype is set, so autocmds see the buffer var
          on_pre_filetype = function(bufnr)
            vim.b[bufnr].ssns_skip_semantic_highlight = true
          end,
          use_basic_highlighting = true,
        },
      },
    },
    total_width_ratio = 0.70,
    total_height_ratio = 0.70,
    initial_focus = "buffers",
    augroup_name = "SSNSQueryHistory",
    controls = {
      {
        header = "Navigation",
        keys = {
          { key = "j/k", desc = "Navigate up/down" },
          { key = "Tab", desc = "Switch panels" },
          { key = "S-Tab", desc = "Previous panel" },
        },
      },
      {
        header = "Search",
        keys = {
          { key = "/", desc = "Activate search" },
          { key = "A-c", desc = "Toggle case sensitive (in search)" },
          { key = "A-r", desc = "Toggle regex mode (in search)" },
          { key = "A-w", desc = "Toggle whole word (in search)" },
        },
      },
      {
        header = "Actions",
        keys = {
          { key = "Enter", desc = "Load selected query" },
          { key = "d", desc = "Delete entry/buffer" },
          { key = "c", desc = "Clear all history" },
          { key = "x", desc = "Export history" },
          { key = "q/Esc", desc = "Close" },
        },
      },
    },
    on_close = function()
      -- Clean up search autocmds
      if search_augroup then
        pcall(vim.api.nvim_del_augroup_by_id, search_augroup)
        search_augroup = nil
      end
      multi_panel = nil
      ui_state = {
        all_buffer_histories = {},
        buffer_histories = {},
        entry_matches = {},
        selected_buffer_idx = 1,
        selected_entry_idx = 1,
        search_term = "",
        search_term_before_edit = "",
        search_editing = false,
        search_case_sensitive = false,
        search_use_regex = true,
        search_whole_word = false,
        search_in_progress = false,
        search_progress = 0,
        search_cancel_token = nil,
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
    [km.search or "/"] = activate_search,
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
    [km.search or "/"] = activate_search,
  })

  -- Setup keymaps for preview panel (limited - just close, navigate, and search)
  multi_panel:set_panel_keymaps("preview", {
    [common.close or "q"] = function() UiHistory.close() end,
    [common.cancel or "<Esc>"] = function() UiHistory.close() end,
    [common.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [common.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
    [km.search or "/"] = activate_search,
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
