---@class UiHistory
---Query history UI with 3-panel floating window layout using UiFloat
local UiHistory = {}

local UiFloat = require('nvim-float.window')
local ContentBuilder = require('nvim-float.content')
local QueryHistory = require('nvim-ssns.query_history')
local UiQuery = require('nvim-ssns.ui.core.query')
local Cache = require('nvim-ssns.cache')
local KeymapManager = require('nvim-ssns.keymap_manager')
local Spinner = require('nvim-ssns.async.spinner')
local Cancellation = require('nvim-ssns.async.cancellation')
local Thread = require('nvim-ssns.async.thread')

-- Lazy load ETL history module
local EtlHistoryModule
local function get_etl_history()
  if not EtlHistoryModule then
    local ok, mod = pcall(require, "ssns.history.etl_metadata")
    if ok then
      EtlHistoryModule = mod
    end
  end
  return EtlHistoryModule
end

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
  filter_etl_only = false,  -- Show only ETL entries when true
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
    filter_etl_only = false,
  }
end

---Toggle ETL-only filter
local function toggle_etl_filter()
  ui_state.filter_etl_only = not ui_state.filter_etl_only

  -- Re-apply filters
  apply_filters()

  if multi_panel then
    multi_panel:render_all()
  end

  local status = ui_state.filter_etl_only and "ETL scripts only" or "All entries"
  vim.notify("History filter: " .. status, vim.log.levels.INFO)
end

---Apply all filters (search + ETL filter)
local function apply_filters()
  local etl_history = get_etl_history()

  -- Start from all buffers
  local filtered_buffers = {}

  for _, buffer_history in ipairs(ui_state.all_buffer_histories) do
    -- If ETL filter is on, filter out non-ETL entries within each buffer
    if ui_state.filter_etl_only and etl_history then
      local filtered_entries = {}
      for _, entry in ipairs(buffer_history.entries) do
        if etl_history.is_etl_entry(entry) then
          table.insert(filtered_entries, entry)
        end
      end

      if #filtered_entries > 0 then
        -- Create a filtered view of this buffer history
        local filtered_buffer = vim.tbl_extend("force", {}, buffer_history)
        filtered_buffer.entries = filtered_entries
        table.insert(filtered_buffers, filtered_buffer)
      end
    else
      table.insert(filtered_buffers, buffer_history)
    end
  end

  ui_state.buffer_histories = filtered_buffers

  -- Reset selection if out of bounds
  if ui_state.selected_buffer_idx > #ui_state.buffer_histories then
    ui_state.selected_buffer_idx = math.max(1, #ui_state.buffer_histories)
  end
  ui_state.selected_entry_idx = 1
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
---@return string[] lines, table[] highlights, ContentBuilder cb
local function render_buffers(state)
  local cb = ContentBuilder.new()
  local stats = QueryHistory.get_stats()

  -- Header
  cb:line("")
  cb:line(string.format(" Total: %d buffers | %d entries", stats.total_buffers, stats.total_entries), "NvimFloatHint")
  cb:line(string.format(" Success: %d | Errors: %d", stats.success_count, stats.error_count), "NvimFloatHint")
  cb:line("")

  for i, buffer_history in ipairs(ui_state.buffer_histories) do
    local entry_count = #buffer_history.entries
    local db_suffix = buffer_history.database and ("/" .. buffer_history.database) or ""

    cb:spans({
      { text = " " },
      { text = buffer_history.buffer_name, style = "NvimFloatHint",
        track = {
          name = "buffer_" .. i,
          type = "buffer",
          data = { buffer_history = buffer_history, index = i },
          row_based = true,
        },
      },
      { text = string.format(" (%s%s) - %d %s",
          buffer_history.server_name,
          db_suffix,
          entry_count,
          entry_count == 1 and "entry" or "entries"
        ), style = "Comment" },
    })
  end

  if #ui_state.buffer_histories == 0 then
    cb:styled("   (No history)", "NvimFloatHint")
  end

  local lines = cb:build_lines()
  local highlights = cb:build_highlights()

  -- Associate ContentBuilder with panel for element tracking
  if multi_panel then
    multi_panel:set_panel_content_builder("buffers", cb)
  end

  return lines, highlights, cb
end

---Render the history list panel
---@param state MultiPanelState
---@return string[] lines, table[] highlights, ContentBuilder cb
local function render_history(state)
  local cb = ContentBuilder.new()

  -- Show search progress if searching
  if ui_state.search_in_progress then
    local spinner_char = get_search_spinner_frame()
    if spinner_char == "" then spinner_char = "⠋" end

    cb:line("")
    cb:line(string.format(" %s Searching... %d%%", spinner_char, ui_state.search_progress), "NvimFloatHint")

    if #ui_state.buffer_histories > 0 then
      cb:line(string.format(" %d matches so far", #ui_state.buffer_histories), "SsnsStatusConnected")
    end
    cb:line("")
  end

  if ui_state.selected_buffer_idx < 1 or ui_state.selected_buffer_idx > #ui_state.buffer_histories then
    if not ui_state.search_in_progress then
      cb:line("")
      cb:styled(" No buffer selected", "NvimFloatHint")
    end
    local lines = cb:build_lines()
  local highlights = cb:build_highlights()
    if multi_panel then
      multi_panel:set_panel_content_builder("history", cb)
    end
    return lines, highlights, cb
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
    cb:line("")
  end
  cb:line(string.format(" %s", buffer_history.buffer_name), "NvimFloatTitle")
  cb:line("")

  for i, entry in ipairs(buffer_history.entries) do
    -- Determine icon based on source, status, and type
    local status_icon, icon_hl
    local etl_history = get_etl_history()
    local is_etl = etl_history and etl_history.is_etl_entry(entry)

    if is_etl then
      -- ETL entry - use special icon
      status_icon = etl_history.get_etl_icon(entry)
      if entry.status == "success" then
        icon_hl = "SsnsStatusConnected"
      else
        icon_hl = "SsnsStatusError"
      end
    elseif entry.source == "auto_save" then
      status_icon = "[A]"
      icon_hl = "NvimFloatHint"
    elseif entry.status == "success" then
      status_icon = "✓"
      icon_hl = "SsnsStatusConnected"
    else
      status_icon = "✗"
      icon_hl = "SsnsStatusError"
    end

    -- Get first line of query (no normalization - display exactly as saved)
    -- For ETL entries, show the ETL summary instead of raw script
    local query_preview, was_truncated
    if is_etl then
      query_preview = etl_history.get_etl_summary(entry)
      was_truncated = false
    else
      local first_newline = entry.query:find("\n")
      query_preview = first_newline and entry.query:sub(1, first_newline - 1) or entry.query
      was_truncated = false
      if #query_preview > 50 then
        query_preview = query_preview:sub(1, 50)
        was_truncated = true
      end
    end

    -- Check for search matches
    local match_positions = nil
    if orig_buf_idx then
      local match_key = string.format("%d:%d", orig_buf_idx, i)
      match_positions = ui_state.entry_matches[match_key]
    end

    -- Build spans for this entry
    local spans = {
      { text = " " },
      { text = status_icon, style = icon_hl },
      { text = string.format(" %s | %dms | ",
          entry.timestamp:sub(12, 19),  -- HH:MM:SS
          entry.execution_time_ms or 0
        ), style = "Comment" },
    }

    -- Add query preview with match highlighting
    if match_positions and #match_positions > 0 then
      -- Build query text with highlighted matches
      local last_end = 1
      for _, pos in ipairs(match_positions) do
        if pos.start <= #query_preview then
          -- Text before match
          if pos.start > last_end then
            table.insert(spans, { text = query_preview:sub(last_end, pos.start - 1) })
          end
          -- Matched text
          local match_end = math.min(pos.end_, #query_preview)
          table.insert(spans, { text = query_preview:sub(pos.start, match_end), style = "SsnsSearchMatch" })
          last_end = match_end + 1
        end
      end
      -- Remaining text after last match
      if last_end <= #query_preview then
        table.insert(spans, { text = query_preview:sub(last_end) })
      end
    else
      table.insert(spans, { text = query_preview })
    end

    if was_truncated then
      table.insert(spans, { text = "...", style = "Comment" })
    end

    -- Add element tracking to the first significant span
    spans[2].track = {
      name = "entry_" .. i,
      type = "entry",
      data = { entry = entry, index = i, buffer_history = buffer_history },
      row_based = true,
    }

    cb:spans(spans)
  end

  if #buffer_history.entries == 0 then
    cb:styled("   (No entries)", "NvimFloatHint")
  end

  local lines = cb:build_lines()
  local highlights = cb:build_highlights()

  -- Associate ContentBuilder with panel for element tracking
  if multi_panel then
    multi_panel:set_panel_content_builder("history", cb)
  end

  return lines, highlights, cb
end

---Render the code preview panel
---@param state MultiPanelState
---@return string[] lines, table[] highlights, ContentBuilder cb
local function render_preview(state)
  local cb = ContentBuilder.new()

  if ui_state.selected_buffer_idx < 1 or ui_state.selected_buffer_idx > #ui_state.buffer_histories then
    cb:styled("-- No buffer selected", "Comment")
    local lines = cb:build_lines()
    local highlights = cb:build_highlights()
    return lines, highlights, cb
  end

  local buffer_history = ui_state.buffer_histories[ui_state.selected_buffer_idx]

  if ui_state.selected_entry_idx < 1 or ui_state.selected_entry_idx > #buffer_history.entries then
    cb:styled("-- No entry selected", "Comment")
    local lines = cb:build_lines()
    local highlights = cb:build_highlights()
    return lines, highlights, cb
  end

  local entry = buffer_history.entries[ui_state.selected_entry_idx]
  local etl_history = get_etl_history()
  local is_etl = etl_history and etl_history.is_etl_entry(entry)

  -- Add metadata header as SQL comments
  cb:line(string.format("-- Buffer: %s", buffer_history.buffer_name), "Comment")
  cb:line(string.format("-- Server: %s | Database: %s",
    buffer_history.server_name, buffer_history.database or "N/A"), "Comment")

  -- Show different info based on source type and ETL status
  if is_etl then
    -- ETL-specific header
    local meta = entry.etl_metadata
    cb:line(string.format("-- Time: %s | Duration: %dms | Type: ETL Script",
      entry.timestamp, entry.execution_time_ms or 0), "Comment")
    cb:line(string.format("-- Blocks: %d total, %d completed, %d failed",
      meta.blocks_total, meta.blocks_completed, meta.blocks_failed), "Comment")

    if entry.status == "error" then
      cb:line(string.format("-- Error: %s", entry.error_message or "Script execution failed"), "Comment")
    end

    -- Add ETL block breakdown
    local block_lines = etl_history.format_block_results(entry)
    for _, line in ipairs(block_lines) do
      cb:line(line, "Comment")
    end
  elseif entry.source == "auto_save" then
    cb:line(string.format("-- Time: %s | Type: Auto-Save", entry.timestamp), "Comment")
  else
    cb:line(string.format("-- Time: %s | Duration: %dms | Status: %s",
      entry.timestamp, entry.execution_time_ms or 0, entry.status), "Comment")

    if entry.status == "error" then
      cb:line(string.format("-- Error: %s", entry.error_message or "Unknown"), "Comment")
    elseif entry.row_count then
      cb:line(string.format("-- Rows: %d", entry.row_count), "Comment")
    end
  end

  -- Show selection info if this was a partial execution
  if entry.selection then
    cb:line(string.format("-- Selection: lines %d-%d (executed portion highlighted)",
      entry.selection.start_line, entry.selection.end_line), "Comment")
  end

  cb:styled("", "Comment")
  cb:line("-- " .. string.rep("─", 40), "Comment")
  cb:line("")

  -- Track where content starts (for selection highlighting)
  local content_start_line = cb:line_count()

  -- Get match positions for search highlighting
  local orig_buf_idx = nil
  for idx, bh in ipairs(ui_state.all_buffer_histories) do
    if bh == buffer_history then
      orig_buf_idx = idx
      break
    end
  end

  local match_positions = nil
  if orig_buf_idx then
    local match_key = string.format("%d:%d", orig_buf_idx, ui_state.selected_entry_idx)
    match_positions = ui_state.entry_matches[match_key]
  end

  -- Determine what content to show: full buffer or just the query
  local display_content = entry.buffer_content or entry.query
  local content_lines = vim.split(display_content, "\n")

  -- Build line-by-line with selection and search highlighting
  for line_idx, content_line in ipairs(content_lines) do
    -- Check if this line is within the executed selection
    local in_selection = false
    if entry.selection and entry.buffer_content then
      in_selection = line_idx >= entry.selection.start_line and line_idx <= entry.selection.end_line
    end

    -- For search match highlighting, we need to track position in query (not buffer_content)
    -- Search matches are relative to entry.query, so only apply when showing query directly
    local line_matches = {}
    if match_positions and #match_positions > 0 and not entry.buffer_content then
      -- Calculate character position for this line in the query
      local char_pos = 1
      for i = 1, line_idx - 1 do
        char_pos = char_pos + #content_lines[i] + 1  -- +1 for newline
      end
      local line_start = char_pos
      local line_end = char_pos + #content_line - 1

      for _, pos in ipairs(match_positions) do
        if pos.end_ >= line_start and pos.start <= line_end then
          table.insert(line_matches, {
            col_start = math.max(1, pos.start - line_start + 1),
            col_end = math.min(#content_line, pos.end_ - line_start + 1),
          })
        end
      end
    end

    -- Build spans for this line
    if #line_matches > 0 then
      -- Search match highlighting takes priority
      local spans = {}
      local last_end = 1
      for _, m in ipairs(line_matches) do
        if m.col_start > last_end then
          table.insert(spans, { text = content_line:sub(last_end, m.col_start - 1) })
        end
        table.insert(spans, { text = content_line:sub(m.col_start, m.col_end), style = "SsnsSearchMatch" })
        last_end = m.col_end + 1
      end
      if last_end <= #content_line then
        table.insert(spans, { text = content_line:sub(last_end) })
      end
      cb:spans(spans)
    elseif in_selection then
      -- Highlight executed selection with a distinct style
      cb:styled(content_line, "Visual")
    else
      cb:line(content_line)
    end
  end

  local lines = cb:build_lines()
  local highlights = cb:build_highlights()
  return lines, highlights, cb
end

---Build the search settings hint line
---@return string line, table[] highlights (relative to this line)
local function build_search_settings_line()
  local case_state = ui_state.search_case_sensitive and "On" or "Off"
  local regex_state = ui_state.search_use_regex and "On" or "Off"
  local word_state = ui_state.search_whole_word and "On" or "Off"
  local etl_state = ui_state.filter_etl_only and "On" or "Off"

  -- Format: " A-c Case:Off | A-r Regex:On | A-w Word:Off | e ETL:Off"
  local line = string.format(" A-c Case:%s | A-r Regex:%s | A-w Word:%s | e ETL:%s",
    case_state, regex_state, word_state, etl_state)

  -- Simple highlight - just highlight the whole line as Comment
  -- States will be highlighted based on their value
  local highlights = {}
  table.insert(highlights, {0, 0, #line, "Comment"})

  return line, highlights
end

---Render the search panel
---@param state MultiPanelState
---@return string[] lines, table[] highlights, ContentBuilder cb
local function render_search(state)
  local cb = ContentBuilder.new()

  if ui_state.search_editing then
    -- Don't render while editing - buffer content is live
    -- Settings line will be shown via virtual text in activate_search
    return {""}, {}, cb
  end

  -- Line 1: Search term or placeholder
  if ui_state.search_term == "" then
    cb:styled(" Press / to search", "Comment")
  else
    cb:styled(" " .. ui_state.search_term, "NvimFloatHint")
  end

  -- Line 2: Settings hints
  local settings_line, _ = build_search_settings_line()
  cb:styled(settings_line, "Comment")

  local lines = cb:build_lines()
  local highlights = cb:build_highlights()
  return lines, highlights, cb
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

---Get buffer element at cursor
---@return table|nil element The element data or nil
local function get_buffer_at_cursor()
  if not multi_panel then return nil end
  local element = multi_panel:get_element_at_cursor()
  if element and element.type == "buffer" then
    return element.data
  end
  return nil
end

---Get entry element at cursor
---@return table|nil element The element data or nil
local function get_entry_at_cursor()
  if not multi_panel then return nil end
  local element = multi_panel:get_element_at_cursor()
  if element and element.type == "entry" then
    return element.data
  end
  return nil
end

---Select buffer at cursor and update history panel
local function select_buffer_at_cursor()
  local buffer_data = get_buffer_at_cursor()
  if not buffer_data then return end

  ui_state.selected_buffer_idx = buffer_data.index
  ui_state.selected_entry_idx = 1

  -- Re-render history and preview panels
  if multi_panel then
    multi_panel:render_panel("history")
    multi_panel:render_panel("preview")
  end
end

---Load selected query into new buffer
local function load_query()
  local buffer_history, entry

  -- Check which panel we're in
  if multi_panel and multi_panel.focused_panel == "buffers" then
    local buffer_data = get_buffer_at_cursor()
    if not buffer_data then return end
    buffer_history = buffer_data.buffer_history
    -- Load first entry when selecting from buffers panel
    entry = buffer_history.entries[1]
  elseif multi_panel and multi_panel.focused_panel == "history" then
    local entry_data = get_entry_at_cursor()
    if not entry_data then return end
    buffer_history = entry_data.buffer_history
    entry = entry_data.entry
  else
    return
  end

  if not entry then return end

  -- Capture values before closing
  local server_name = buffer_history.server_name
  local database_name = buffer_history.database
  local history_buffer_id = buffer_history.buffer_id
  local buffer_name = buffer_history.buffer_name
  local timestamp = entry.timestamp
  -- Use full buffer content if available, otherwise just the executed query
  local query_content = entry.buffer_content or entry.query
  local selection_info = entry.selection  -- May be nil if not a selection execution

  -- Close history window first
  UiHistory.close()

  -- Check if server is already connected and loaded
  local server = Cache.find_server(server_name)
  local database = nil
  local needs_async_connect = false

  if server then
    -- Server exists in cache - check if loaded
    if server.is_loaded then
      -- Server is loaded, try to find database
      if database_name then
        database = server:find_database(database_name)
      end
    else
      -- Server exists but not loaded - need async connect
      needs_async_connect = true
    end
  else
    -- Server not in cache - need to connect via saved connections
    needs_async_connect = true
  end

  -- Create query buffer immediately (without sql to avoid USE prepending)
  -- Pass strings for server/database - we'll update with real objects after async connect
  local query_buf = UiQuery.create_query_buffer(
    server or server_name,
    database or database_name,
    nil,  -- Don't pass sql here - history already has exact content
    nil,  -- object_name
    history_buffer_id  -- Continue this history
  )

  -- Set buffer content directly (history entries are stored exactly as written)
  vim.api.nvim_buf_set_lines(query_buf, 0, -1, false, vim.split(query_content, "\n"))

  -- If this was a selection execution, restore the visual selection
  if selection_info then
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(query_buf) then return end

      -- Find the window displaying this buffer
      local win = vim.fn.bufwinid(query_buf)
      if win == -1 then return end

      -- Set cursor to selection start
      vim.api.nvim_win_set_cursor(win, { selection_info.start_line, selection_info.start_col - 1 })

      -- Enter visual mode and select to end position
      -- Use the appropriate visual mode based on what was used originally
      local mode_key = "v"  -- Default to charwise
      if selection_info.mode == "V" then
        mode_key = "V"
      elseif selection_info.mode == "\x16" then
        mode_key = "<C-v>"
      end

      -- Enter visual mode and move to end of selection
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes(mode_key, true, false, true),
        "n",
        false
      )

      -- Move to end position
      vim.api.nvim_win_set_cursor(win, { selection_info.end_line, selection_info.end_col - 1 })
    end)
  end

  if needs_async_connect then
    -- Start connecting spinner in lualine
    UiQuery.start_connecting(query_buf, server_name, database_name)

    -- Load connections async to find the server config
    local Connections = require('nvim-ssns.connections')
    Connections.load_async(function(connections, err)
      if err or not connections then
        UiQuery.stop_connecting(query_buf, nil, nil)
        vim.notify(
          string.format("Loaded query from %s (%s) - failed to load connections", buffer_name, timestamp),
          vim.log.levels.WARN
        )
        return
      end

      -- Find the connection config for this server
      local conn_config = nil
      for _, conn in ipairs(connections) do
        if conn.name == server_name then
          conn_config = conn
          break
        end
      end

      if not conn_config then
        UiQuery.stop_connecting(query_buf, nil, nil)
        vim.notify(
          string.format("Loaded query from %s (%s) - server '%s' not found in connections", buffer_name, timestamp, server_name),
          vim.log.levels.WARN
        )
        return
      end

      -- Find or create server from connection config
      local found_server, create_err = Cache.find_or_create_server(server_name, conn_config)
      if not found_server then
        UiQuery.stop_connecting(query_buf, nil, nil)
        vim.notify(
          string.format("Loaded query from %s (%s) - failed to create server: %s", buffer_name, timestamp, create_err or "unknown"),
          vim.log.levels.WARN
        )
        return
      end

      -- Connect and load async
      found_server:connect_and_load_async({
        on_complete = function(success, connect_err)
          if not success then
            UiQuery.stop_connecting(query_buf, nil, nil)
            vim.notify(
              string.format("Loaded query from %s (%s) - connection failed: %s", buffer_name, timestamp, connect_err or "unknown"),
              vim.log.levels.WARN
            )
            return
          end

          -- Find database now that server is loaded
          local found_database = nil
          if database_name then
            found_database = found_server:find_database(database_name)
          end

          -- Stop spinner and update buffer with real server/database objects
          UiQuery.stop_connecting(query_buf, found_server, found_database)

          local status_msg = ""
          if not found_database and database_name then
            status_msg = string.format(" (database '%s' not found)", database_name)
          end

          vim.notify(
            string.format("Loaded query from %s (%s) - connected to %s%s", buffer_name, timestamp, server_name, status_msg),
            vim.log.levels.INFO
          )
        end,
      })
    end)
  else
    -- Server already connected and loaded
    vim.notify(
      string.format("Loaded query from %s (%s)", buffer_name, timestamp),
      vim.log.levels.INFO
    )
  end
end

---Delete current entry or buffer
local function delete_entry()
  if not multi_panel then return end

  if multi_panel.focused_panel == "history" then
    -- Delete single entry - use element tracking
    local entry_data = get_entry_at_cursor()
    if not entry_data then return end

    local buffer_history = entry_data.buffer_history
    local entry_idx = entry_data.index

    table.remove(buffer_history.entries, entry_idx)

    if QueryHistory.auto_persist then
      QueryHistory.save_to_file()
    end

    vim.notify("History entry deleted", vim.log.levels.INFO)
    multi_panel:render_all()

  elseif multi_panel.focused_panel == "buffers" then
    -- Delete entire buffer history - use element tracking
    local buffer_data = get_buffer_at_cursor()
    if not buffer_data then return end

    local buffer_history = buffer_data.buffer_history
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
      cb:line(string.format("  Contains %d history entries.", count), "NvimFloatHint")
      cb:line("")
      cb:styled("  Press <Enter> to confirm, <Esc> to cancel", "Comment")
      confirm_win:render()

      local confirm_keymaps = {
        ["<CR>"] = function()
          confirm_win:close()
          QueryHistory.clear_buffer_history(buffer_history.buffer_id)

          -- Refresh
          ui_state.all_buffer_histories = QueryHistory.get_all_buffer_histories()
          ui_state.buffer_histories = ui_state.all_buffer_histories

          if #ui_state.buffer_histories == 0 then
            UiHistory.close()
            vim.notify("All history cleared", vim.log.levels.INFO)
          else
            ui_state.selected_buffer_idx = 1
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
    cb:styled("  ⚠ Clear ALL query history?", "WarningMsg")
    cb:line(string.format("  %d buffers, %d entries will be deleted.", stats.total_buffers, stats.total_entries), "NvimFloatHint")
    cb:line("")
    cb:styled("  Press <Enter> to confirm, <Esc> to cancel", "Comment")
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
  local default_path = vim.fn.stdpath('data') .. '/nvim-ssns/history_export.txt'

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
    cb:styled("  Export query history to file:", "NvimFloatTitle")
    cb:line("")
    cb:labeled_input("filepath", "  File", {
      value = default_path,
      placeholder = "(enter path)",
      width = 50,  -- Default width, expands for longer paths
    })
    cb:line("")
    cb:styled("  Use .json extension for JSON format, otherwise plain text.", "Comment")
    cb:line("")
    cb:styled("  <Enter>=Export | <Esc>=Cancel", "NvimFloatHint")
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
    filter_etl_only = false,
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
              cursorline = true,  -- Visual selection via cursorline
              on_render = render_buffers,
              on_focus = function()
                if multi_panel then
                  multi_panel:update_panel_title("buffers", "Buffers ●")
                  multi_panel:update_panel_title("history", "History")
                  -- Update selected buffer based on cursor when focusing
                  select_buffer_at_cursor()
                end
              end,
            },
            {
              name = "history",
              title = "History",
              ratio = 0.44,  -- Shorter history list
              cursorline = true,  -- Visual selection via cursorline
              on_render = render_history,
              on_focus = function()
                if multi_panel then
                  multi_panel:update_panel_title("buffers", "Buffers")
                  multi_panel:update_panel_title("history", "History ●")
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
          { key = "j/k/arrows", desc = "Navigate (vim motions)" },
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
          { key = "e", desc = "Toggle ETL filter" },
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
        filter_etl_only = false,
      }
    end,
  })

  if not multi_panel then
    return
  end

  -- Render all panels
  multi_panel:render_all()

  -- Setup keymaps for buffers panel
  -- Uses standard vim navigation (j/k), only Enter for interaction
  multi_panel:set_panel_keymaps("buffers", {
    [common.close or "q"] = function() UiHistory.close() end,
    [common.cancel or "<Esc>"] = function() UiHistory.close() end,
    [common.confirm or "<CR>"] = function()
      -- Select buffer and update history panel, then load query
      select_buffer_at_cursor()
      load_query()
    end,
    [common.next_field or "<Tab>"] = function()
      -- Update selected buffer before switching panels
      select_buffer_at_cursor()
      multi_panel:focus_next_panel()
    end,
    [common.prev_field or "<S-Tab>"] = function()
      select_buffer_at_cursor()
      multi_panel:focus_prev_panel()
    end,
    [km.delete or "d"] = delete_entry,
    [km.clear_all or "c"] = clear_all,
    [km.export or "x"] = export_history,
    [km.search or "/"] = activate_search,
    ["e"] = toggle_etl_filter,
  })

  -- Setup keymaps for history panel
  -- Uses standard vim navigation (j/k), only Enter for interaction
  multi_panel:set_panel_keymaps("history", {
    [common.close or "q"] = function() UiHistory.close() end,
    [common.cancel or "<Esc>"] = function() UiHistory.close() end,
    [common.confirm or "<CR>"] = load_query,
    [common.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [common.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
    [km.delete or "d"] = delete_entry,
    [km.clear_all or "c"] = clear_all,
    [km.export or "x"] = export_history,
    [km.search or "/"] = activate_search,
    ["e"] = toggle_etl_filter,
  })

  -- Setup keymaps for preview panel (limited - just close and search)
  multi_panel:set_panel_keymaps("preview", {
    [common.close or "q"] = function() UiHistory.close() end,
    [common.cancel or "<Esc>"] = function() UiHistory.close() end,
    [common.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [common.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
    [km.search or "/"] = activate_search,
  })

  -- Setup CursorMoved autocmds for master-detail updates
  local history_augroup = vim.api.nvim_create_augroup("SSNSHistoryCursor", { clear = true })

  -- When cursor moves in buffers panel, update history + preview
  local buffers_buf = multi_panel:get_panel_buffer("buffers")
  if buffers_buf then
    vim.api.nvim_create_autocmd("CursorMoved", {
      group = history_augroup,
      buffer = buffers_buf,
      callback = function()
        local buffer_data = get_buffer_at_cursor()
        if buffer_data and buffer_data.index ~= ui_state.selected_buffer_idx then
          ui_state.selected_buffer_idx = buffer_data.index
          ui_state.selected_entry_idx = 1
          if multi_panel then
            multi_panel:render_panel("history")
            multi_panel:render_panel("preview")
          end
        end
      end,
    })
  end

  -- When cursor moves in history panel, update preview
  local history_buf = multi_panel:get_panel_buffer("history")
  if history_buf then
    vim.api.nvim_create_autocmd("CursorMoved", {
      group = history_augroup,
      buffer = history_buf,
      callback = function()
        local entry_data = get_entry_at_cursor()
        if entry_data and entry_data.index ~= ui_state.selected_entry_idx then
          ui_state.selected_entry_idx = entry_data.index
          if multi_panel then
            multi_panel:render_panel("preview")
          end
        end
      end,
    })
  end

  -- Position cursor on first element (after render is complete)
  vim.schedule(function()
    if multi_panel and multi_panel:is_valid() then
      -- Set cursor to first buffer element (line 5: header lines + first buffer)
      multi_panel:set_cursor("buffers", 5, 0)
    end
  end)

  -- Mark focus on initial panel
  multi_panel:update_panel_title("buffers", "Buffers ●")
end

return UiHistory
