---@class UiHistory
---Query history UI with 3-panel floating window layout
local UiHistory = {}

local QueryHistory = require('ssns.query_history')
local UiQuery = require('ssns.ui.core.query')
local Cache = require('ssns.cache')

---@class HistoryState
---@field buffers_buf number Buffer list buffer
---@field buffers_win number Buffer list window
---@field history_buf number History list buffer
---@field history_win number History list window
---@field code_buf number Code preview buffer
---@field code_win number Code preview window
---@field footer_buf number Footer buffer
---@field footer_win number Footer window
---@field buffer_histories QueryBufferHistory[] All buffer histories
---@field selected_buffer_idx number Currently selected buffer index
---@field selected_entry_idx number Currently selected entry index
---@field active_panel "buffers"|"history"|"preview" Currently focused panel
---@field last_panel "buffers"|"history" Last focused panel before preview

---@type HistoryState?
local state = nil

---Create custom borders with T-junctions for unified appearance
---@return table borders Custom borders for each panel
local function create_custom_borders()
  -- Box drawing characters
  local chars = {
    horizontal = "─",
    vertical = "│",
    top_left = "╭",
    top_right = "╮",
    bottom_left = "╰",
    bottom_right = "╯",
    t_right = "├",  -- T pointing right
    t_left = "┤",   -- T pointing left
    t_down = "┬",   -- T pointing down
    t_up = "┴",     -- T pointing up
    cross = "┼",    -- Cross/4-way junction
  }

  return {
    -- Buffer list: top-left panel
    -- Top-left rounded, top-right T-down, bottom-left T-right, bottom-right cross
    buffer_list = {
      chars.top_left,      -- [1] top-left
      chars.horizontal,    -- [2] top
      chars.t_down,        -- [3] top-right (T-junction down to preview)
      chars.vertical,      -- [4] right
      chars.cross,         -- [5] bottom-right (4-way junction)
      chars.horizontal,    -- [6] bottom
      chars.t_right,       -- [7] bottom-left (T-junction right to history)
      chars.vertical,      -- [8] left
    },

    -- History: bottom-left panel
    -- Top-left T-right, top-right cross, bottom-left rounded, bottom-right T-down
    history = {
      chars.t_right,       -- [1] top-left (T-junction from buffer list)
      chars.horizontal,    -- [2] top
      chars.cross,         -- [3] top-right (4-way junction)
      chars.vertical,      -- [4] right
      chars.t_up,          -- [5] bottom-right (T-junction up to preview)
      chars.horizontal,    -- [6] bottom
      chars.bottom_left,   -- [7] bottom-left (rounded)
      chars.vertical,      -- [8] left
    },

    -- Preview: right panel (full height)
    -- Top-left T-down, top-right rounded, bottom-left T-up, bottom-right rounded
    preview = {
      chars.t_down,        -- [1] top-left (T-junction from buffer list)
      chars.horizontal,    -- [2] top
      chars.top_right,     -- [3] top-right (rounded)
      chars.vertical,      -- [4] right
      chars.bottom_right,  -- [5] bottom-right (rounded)
      chars.horizontal,    -- [6] bottom
      chars.t_up,          -- [7] bottom-left (T-junction from history)
      chars.vertical,      -- [8] left
    },
  }
end

---Calculate layout for 3-panel floating windows
---@param cols number Terminal columns
---@param lines number Terminal lines
---@return table layout Panel configurations
local function calculate_layout(cols, lines)
  -- Overall dimensions: 60% width x 80% height, centered
  local total_width = math.floor(cols * 0.6)
  local total_height = math.floor(lines * 0.8)
  local start_row = math.floor((lines - total_height) / 2)
  local start_col = math.floor((cols - total_width) / 2)

  -- Account for borders (each border adds 2 to width/height: 1 on each side)
  -- But shared borders don't add extra width/height

  -- Left panels: 40% of total width (minus border consideration)
  -- Right panel: 60% of total width
  local left_width = math.floor(total_width * 0.4)
  local right_width = total_width - left_width - 1  -- -1 for shared border

  -- Top-left panel: 40% of total height
  -- Bottom-left panel: 60% of total height
  local top_height = math.floor(total_height * 0.4)
  local bottom_height = total_height - top_height - 1  -- -1 for shared border

  local borders = create_custom_borders()

  return {
    buffer_list = {
      relative = "editor",
      width = left_width,
      height = top_height,
      row = start_row,
      col = start_col,
      style = "minimal",
      border = borders.buffer_list,
      title = " Buffers ",
      title_pos = "center",
      zindex = 50,
      focusable = true,
    },
    history = {
      relative = "editor",
      width = left_width,
      height = bottom_height,
      row = start_row + top_height + 1,  -- +1 to account for buffer list's bottom border
      col = start_col,
      style = "minimal",
      border = borders.history,
      title = " History ",
      title_pos = "center",
      zindex = 51,  -- Higher z-index so title stays visible above buffer's bottom border
      focusable = true,
    },
    preview = {
      relative = "editor",
      width = right_width,
      height = total_height,
      row = start_row,
      col = start_col + left_width + 1,  -- +1 to account for left panels' right border
      style = "minimal",
      border = borders.preview,
      title = " Code Preview ",
      title_pos = "center",
      zindex = 50,  -- Same z-index
      focusable = true,
    },
    footer = {
      text = " <Tab>=Switch | <S-Tab>=Preview | <CR>=Load | d=Delete | c=Clear | x=Export | /=Search | q=Close ",
      row = start_row + total_height + 2,  -- +2 to account for bottom border
      col = start_col,
      width = total_width,
    }
  }
end

---Show query history in 3-panel layout
---@param options table? Options {server: string?, database: string?}
function UiHistory.show_history(options)
  options = options or {}

  local buffer_histories = QueryHistory.get_all_buffer_histories()

  if #buffer_histories == 0 then
    vim.notify("No query history available", vim.log.levels.WARN)
    return
  end

  -- Apply filters if provided
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

  -- Initialize state
  state = {
    buffer_histories = buffer_histories,
    selected_buffer_idx = 1,
    selected_entry_idx = 1,
    active_panel = "buffers",
    last_panel = "buffers",
  }

  -- Create the 3-panel layout
  UiHistory._create_layout()

  -- Render initial content
  UiHistory._render_all()

  -- Setup keymaps
  UiHistory._setup_keymaps()

  -- Setup auto-commands for cleanup and resize
  UiHistory._setup_autocmds()
end

---Create the 3-panel floating window layout
function UiHistory._create_layout()
  local layout = calculate_layout(vim.o.columns, vim.o.lines)

  -- Create buffers for each panel
  state.buffers_buf = vim.api.nvim_create_buf(false, true)
  state.history_buf = vim.api.nvim_create_buf(false, true)
  state.code_buf = vim.api.nvim_create_buf(false, true)

  -- Configure buffer options
  for _, bufnr in ipairs({state.buffers_buf, state.history_buf, state.code_buf}) do
    vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  end

  -- Set filetype for code preview (SQL syntax highlighting)
  vim.api.nvim_buf_set_option(state.code_buf, 'filetype', 'sql')

  -- Create floating windows (all with same z-index to prevent overlap on focus)
  state.buffers_win = vim.api.nvim_open_win(state.buffers_buf, true, layout.buffer_list)
  state.history_win = vim.api.nvim_open_win(state.history_buf, false, layout.history)
  state.code_win = vim.api.nvim_open_win(state.code_buf, false, layout.preview)

  -- Configure window options
  for _, winid in ipairs({state.buffers_win, state.history_win, state.code_win}) do
    vim.api.nvim_set_option_value('number', false, { win = winid })
    vim.api.nvim_set_option_value('relativenumber', false, { win = winid })
    vim.api.nvim_set_option_value('cursorline', true, { win = winid })
    vim.api.nvim_set_option_value('wrap', false, { win = winid })
    vim.api.nvim_set_option_value('signcolumn', 'no', { win = winid })
    -- Keep borders and titles visible even when not focused
    vim.api.nvim_set_option_value('winhighlight', 'FloatBorder:FloatBorder,FloatTitle:FloatTitle', { win = winid })
  end

  -- Create footer window (pseudo-window for keybind help)
  state.footer_buf = vim.api.nvim_create_buf(false, true)

  -- Center the footer text
  local text_len = #layout.footer.text
  local padding = math.floor((layout.footer.width - text_len) / 2)
  local centered_text = string.rep(" ", padding) .. layout.footer.text

  vim.api.nvim_buf_set_lines(state.footer_buf, 0, -1, false, {centered_text})
  vim.api.nvim_buf_set_option(state.footer_buf, 'modifiable', false)

  state.footer_win = vim.api.nvim_open_win(state.footer_buf, false, {
    relative = "editor",
    width = layout.footer.width,
    height = 1,
    row = layout.footer.row,
    col = layout.footer.col,
    style = "minimal",
    border = "none",
    zindex = 52,  -- Highest z-index to stay on top of everything
    focusable = false,
  })

  -- Style footer
  vim.api.nvim_set_option_value('winhighlight', 'Normal:Comment', { win = state.footer_win })

  -- Focus buffer list
  vim.api.nvim_set_current_win(state.buffers_win)
end

---Render all panels
function UiHistory._render_all()
  UiHistory._render_buffer_list()
  UiHistory._render_history_list()
  UiHistory._render_code_preview()
end

---Render buffer list panel
function UiHistory._render_buffer_list()
  local lines = {}
  local stats = QueryHistory.get_stats()

  table.insert(lines, string.format("Total: %d buffers | %d entries | %d success | %d errors",
    stats.total_buffers, stats.total_entries, stats.success_count, stats.error_count))
  table.insert(lines, string.rep("─", 50))
  table.insert(lines, "")

  for i, buffer_history in ipairs(state.buffer_histories) do
    local prefix = i == state.selected_buffer_idx and "▶ " or "  "
    local entry_count = #buffer_history.entries

    local line = string.format(
      "%s%s (%s%s) - %d %s",
      prefix,
      buffer_history.buffer_name,
      buffer_history.server_name,
      buffer_history.database and (" / " .. buffer_history.database) or "",
      entry_count,
      entry_count == 1 and "entry" or "entries"
    )
    table.insert(lines, line)
  end

  -- Update buffer
  vim.api.nvim_buf_set_option(state.buffers_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.buffers_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.buffers_buf, 'modifiable', false)

  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace("ssns_history_buffers")
  vim.api.nvim_buf_clear_namespace(state.buffers_buf, ns_id, 0, -1)

  -- Highlight header
  vim.api.nvim_buf_add_highlight(state.buffers_buf, ns_id, "Comment", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(state.buffers_buf, ns_id, "Comment", 1, 0, -1)

  -- Highlight selected buffer
  if state.selected_buffer_idx > 0 then
    local line_idx = state.selected_buffer_idx + 2  -- Account for header lines
    vim.api.nvim_buf_add_highlight(state.buffers_buf, ns_id, "Title", line_idx, 0, -1)
  end

  -- Set cursor to selected buffer
  if vim.api.nvim_win_is_valid(state.buffers_win) and vim.api.nvim_get_current_win() == state.buffers_win then
    pcall(vim.api.nvim_win_set_cursor, state.buffers_win, {state.selected_buffer_idx + 3, 0})
  end
end

---Render history list panel
function UiHistory._render_history_list()
  local lines = {}

  if state.selected_buffer_idx < 1 or state.selected_buffer_idx > #state.buffer_histories then
    table.insert(lines, "No buffer selected")
    vim.api.nvim_buf_set_option(state.history_buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(state.history_buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(state.history_buf, 'modifiable', false)
    return
  end

  local buffer_history = state.buffer_histories[state.selected_buffer_idx]

  table.insert(lines, string.format("History for: %s", buffer_history.buffer_name))
  table.insert(lines, string.rep("─", 50))
  table.insert(lines, "")

  for i, entry in ipairs(buffer_history.entries) do
    local prefix = i == state.selected_entry_idx and "▶ " or "  "
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
  end

  if #buffer_history.entries == 0 then
    table.insert(lines, "  (No history entries)")
  end

  -- Update buffer
  vim.api.nvim_buf_set_option(state.history_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.history_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.history_buf, 'modifiable', false)

  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace("ssns_history_entries")
  vim.api.nvim_buf_clear_namespace(state.history_buf, ns_id, 0, -1)

  -- Highlight header
  vim.api.nvim_buf_add_highlight(state.history_buf, ns_id, "Comment", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(state.history_buf, ns_id, "Comment", 1, 0, -1)

  -- Highlight entries
  for i, entry in ipairs(buffer_history.entries) do
    local line_idx = i + 2  -- Account for header
    local is_selected = i == state.selected_entry_idx

    if is_selected then
      vim.api.nvim_buf_add_highlight(state.history_buf, ns_id, "Title", line_idx, 0, -1)
    end

    -- Highlight status icon
    local hl_group = entry.status == "success" and "DiagnosticOk" or "DiagnosticError"
    local icon_col = is_selected and 4 or 2
    vim.api.nvim_buf_add_highlight(state.history_buf, ns_id, hl_group, line_idx, icon_col, icon_col + 1)
  end

  -- Set cursor to selected entry
  if vim.api.nvim_win_is_valid(state.history_win) and vim.api.nvim_get_current_win() == state.history_win and state.selected_entry_idx > 0 then
    pcall(vim.api.nvim_win_set_cursor, state.history_win, {state.selected_entry_idx + 3, 0})
  end
end

---Render code preview panel
function UiHistory._render_code_preview()
  local lines = {}

  if state.selected_buffer_idx < 1 or state.selected_buffer_idx > #state.buffer_histories then
    table.insert(lines, "-- No buffer selected")
    vim.api.nvim_buf_set_option(state.code_buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(state.code_buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(state.code_buf, 'modifiable', false)
    return
  end

  local buffer_history = state.buffer_histories[state.selected_buffer_idx]

  if state.selected_entry_idx < 1 or state.selected_entry_idx > #buffer_history.entries then
    table.insert(lines, "-- No entry selected")
    vim.api.nvim_buf_set_option(state.code_buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(state.code_buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(state.code_buf, 'modifiable', false)
    return
  end

  local entry = buffer_history.entries[state.selected_entry_idx]

  -- Add metadata header
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
  table.insert(lines, string.rep("-- ", 25))
  table.insert(lines, "")

  -- Add query
  for _, query_line in ipairs(vim.split(entry.query, "\n")) do
    table.insert(lines, query_line)
  end

  -- Update buffer
  vim.api.nvim_buf_set_option(state.code_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.code_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.code_buf, 'modifiable', false)
end

---Setup keymaps for all panels using KeymapManager for conflict handling
function UiHistory._setup_keymaps()
  local KeymapManager = require('ssns.keymap_manager')

  -- Get keymaps from history group (with common as fallback)
  local km = KeymapManager.get_group("history")
  local common = KeymapManager.get_group("common")

  local buffers = {state.buffers_buf, state.history_buf}

  for _, bufnr in ipairs(buffers) do
    -- Build keymap definitions for main panels
    local keymaps = {
      -- Close window
      {
        lhs = common.close or "q",
        rhs = function() UiHistory._close() end,
        desc = "Close history",
      },
      {
        lhs = common.cancel or "<Esc>",
        rhs = function() UiHistory._close() end,
        desc = "Close history",
      },
      -- Switch panels
      {
        lhs = km.switch_panel or common.next_field or "<Tab>",
        rhs = function() UiHistory._switch_panel() end,
        desc = "Switch panel",
      },
      -- Toggle preview
      {
        lhs = km.toggle_preview or common.prev_field or "<S-Tab>",
        rhs = function() UiHistory._toggle_preview() end,
        desc = "Toggle preview",
      },
      -- Navigation
      {
        lhs = common.nav_down or "j",
        rhs = function() UiHistory._move_down() end,
        desc = "Move down",
      },
      {
        lhs = common.nav_up or "k",
        rhs = function() UiHistory._move_up() end,
        desc = "Move up",
      },
      {
        lhs = common.nav_down_alt or "<Down>",
        rhs = function() UiHistory._move_down() end,
        desc = "Move down",
      },
      {
        lhs = common.nav_up_alt or "<Up>",
        rhs = function() UiHistory._move_up() end,
        desc = "Move up",
      },
      -- Load query
      {
        lhs = km.load_query or common.confirm or "<CR>",
        rhs = function() UiHistory._load_query() end,
        desc = "Load query",
      },
      -- Delete
      {
        lhs = km.delete or "d",
        rhs = function() UiHistory._delete_entry() end,
        desc = "Delete entry",
      },
      -- Clear all
      {
        lhs = km.clear_all or "c",
        rhs = function() UiHistory._clear_all() end,
        desc = "Clear all",
      },
      -- Export
      {
        lhs = km.export or "x",
        rhs = function() UiHistory._export() end,
        desc = "Export history",
      },
      -- Search
      {
        lhs = km.search or "/",
        rhs = function() UiHistory._search() end,
        desc = "Search history",
      },
    }

    -- Set all keymaps with conflict handling
    KeymapManager.set_multiple(bufnr, keymaps, true)
    KeymapManager.mark_group_active(bufnr, "history")
  end

  -- Setup keymaps for code preview buffer (allows visual selection but not editing)
  local preview_keymaps = {
    {
      lhs = common.close or "q",
      rhs = function() UiHistory._close() end,
      desc = "Close history",
    },
    {
      lhs = common.cancel or "<Esc>",
      rhs = function() UiHistory._close() end,
      desc = "Close history",
    },
    {
      lhs = km.toggle_preview or common.prev_field or "<S-Tab>",
      rhs = function() UiHistory._toggle_preview() end,
      desc = "Return to last panel",
    },
  }

  KeymapManager.set_multiple(state.code_buf, preview_keymaps, true)
  KeymapManager.mark_group_active(state.code_buf, "history")
end

---Setup autocmds for cleanup and resize
function UiHistory._setup_autocmds()
  local group = vim.api.nvim_create_augroup("SSNSQueryHistory", { clear = true })

  -- Handle window resize
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if state and state.buffers_win and vim.api.nvim_win_is_valid(state.buffers_win) then
        UiHistory._recalculate_layout()
      end
    end,
  })

  -- Cleanup on buffer wipe
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = state.buffers_buf,
    callback = function()
      UiHistory._close()
    end,
  })
end

---Recalculate layout on terminal resize
function UiHistory._recalculate_layout()
  local layout = calculate_layout(vim.o.columns, vim.o.lines)

  -- Update window positions
  if vim.api.nvim_win_is_valid(state.buffers_win) then
    vim.api.nvim_win_set_config(state.buffers_win, layout.buffer_list)
  end
  if vim.api.nvim_win_is_valid(state.history_win) then
    vim.api.nvim_win_set_config(state.history_win, layout.history)
  end
  if vim.api.nvim_win_is_valid(state.code_win) then
    vim.api.nvim_win_set_config(state.code_win, layout.preview)
  end
  if vim.api.nvim_win_is_valid(state.footer_win) then
    -- Recalculate centered footer text
    local text_len = #layout.footer.text
    local padding = math.floor((layout.footer.width - text_len) / 2)
    local centered_text = string.rep(" ", padding) .. layout.footer.text

    vim.api.nvim_buf_set_option(state.footer_buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(state.footer_buf, 0, -1, false, {centered_text})
    vim.api.nvim_buf_set_option(state.footer_buf, 'modifiable', false)

    vim.api.nvim_win_set_config(state.footer_win, {
      relative = "editor",
      width = layout.footer.width,
      height = 1,
      row = layout.footer.row,
      col = layout.footer.col,
      style = "minimal",
      border = "none",
      zindex = 52,  -- Highest z-index to stay on top
      focusable = false,
    })
  end
end

---Close history windows
function UiHistory._close()
  if not state then
    return
  end

  -- Close windows
  for _, win in ipairs({state.buffers_win, state.history_win, state.code_win, state.footer_win}) do
    if win and vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end

  -- Clear autocmds
  pcall(vim.api.nvim_del_augroup_by_name, "SSNSQueryHistory")

  state = nil
end

---Switch between buffer list and history list panels
function UiHistory._switch_panel()
  if state.active_panel == "buffers" then
    state.active_panel = "history"
    state.last_panel = "history"
    if vim.api.nvim_win_is_valid(state.history_win) then
      vim.api.nvim_set_current_win(state.history_win)
      -- Set cursor to selected entry (account for 3 header lines)
      if state.selected_entry_idx > 0 then
        pcall(vim.api.nvim_win_set_cursor, state.history_win, {state.selected_entry_idx + 3, 0})
      end
    end
  elseif state.active_panel == "history" then
    state.active_panel = "buffers"
    state.last_panel = "buffers"
    if vim.api.nvim_win_is_valid(state.buffers_win) then
      vim.api.nvim_set_current_win(state.buffers_win)
      -- Set cursor to selected buffer (account for 3 header lines)
      if state.selected_buffer_idx > 0 then
        pcall(vim.api.nvim_win_set_cursor, state.buffers_win, {state.selected_buffer_idx + 3, 0})
      end
    end
  elseif state.active_panel == "preview" then
    -- If currently in preview, switch back to last panel
    UiHistory._toggle_preview()
  end
end

---Toggle between preview and last focused panel
function UiHistory._toggle_preview()
  if state.active_panel == "preview" then
    -- Return to last panel
    if state.last_panel == "history" then
      state.active_panel = "history"
      if vim.api.nvim_win_is_valid(state.history_win) then
        vim.api.nvim_set_current_win(state.history_win)
        -- Set cursor to selected entry
        if state.selected_entry_idx > 0 then
          pcall(vim.api.nvim_win_set_cursor, state.history_win, {state.selected_entry_idx + 3, 0})
        end
      end
    else
      state.active_panel = "buffers"
      if vim.api.nvim_win_is_valid(state.buffers_win) then
        vim.api.nvim_set_current_win(state.buffers_win)
        -- Set cursor to selected buffer
        if state.selected_buffer_idx > 0 then
          pcall(vim.api.nvim_win_set_cursor, state.buffers_win, {state.selected_buffer_idx + 3, 0})
        end
      end
    end
  else
    -- Switch to preview
    state.last_panel = state.active_panel
    state.active_panel = "preview"
    if vim.api.nvim_win_is_valid(state.code_win) then
      vim.api.nvim_set_current_win(state.code_win)
    end
  end
end

---Move selection down
function UiHistory._move_down()
  if state.active_panel == "buffers" then
    if state.selected_buffer_idx < #state.buffer_histories then
      state.selected_buffer_idx = state.selected_buffer_idx + 1
      state.selected_entry_idx = 1  -- Reset to first entry of new buffer
      UiHistory._render_all()
    end
  else
    local buffer_history = state.buffer_histories[state.selected_buffer_idx]
    if buffer_history and state.selected_entry_idx < #buffer_history.entries then
      state.selected_entry_idx = state.selected_entry_idx + 1
      UiHistory._render_history_list()
      UiHistory._render_code_preview()
    end
  end
end

---Move selection up
function UiHistory._move_up()
  if state.active_panel == "buffers" then
    if state.selected_buffer_idx > 1 then
      state.selected_buffer_idx = state.selected_buffer_idx - 1
      state.selected_entry_idx = 1  -- Reset to first entry of new buffer
      UiHistory._render_all()
    end
  else
    if state.selected_entry_idx > 1 then
      state.selected_entry_idx = state.selected_entry_idx - 1
      UiHistory._render_history_list()
      UiHistory._render_code_preview()
    end
  end
end

---Load selected query into new buffer
function UiHistory._load_query()
  if not state or state.selected_buffer_idx < 1 or state.selected_buffer_idx > #state.buffer_histories then
    return
  end

  local buffer_history = state.buffer_histories[state.selected_buffer_idx]
  local entry = buffer_history.entries[state.selected_entry_idx]

  if not entry then
    return
  end

  -- Look up actual ServerClass and DbClass objects from cache
  local server = Cache.find_server(buffer_history.server_name)
  local database = nil

  if server and buffer_history.database then
    database = Cache.find_database(buffer_history.server_name, buffer_history.database)
  end

  -- Close history window
  UiHistory._close()

  -- Create new query buffer with proper objects (or strings as fallback)
  -- If server/database not found, pass strings - buffer will work for viewing but not execution
  UiQuery.create_query_buffer(server or buffer_history.server_name, database or buffer_history.database)

  -- Populate with query
  vim.schedule(function()
    local query_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_option(query_buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(query_buf, 0, -1, false, vim.split(entry.query, "\n"))

    -- Notify with connection status
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
function UiHistory._delete_entry()
  if not state or state.selected_buffer_idx < 1 then
    return
  end

  local buffer_history = state.buffer_histories[state.selected_buffer_idx]

  if state.active_panel == "history" and state.selected_entry_idx > 0 then
    -- Delete single entry
    table.remove(buffer_history.entries, state.selected_entry_idx)

    if QueryHistory.auto_persist then
      QueryHistory.save_to_file()
    end

    -- Adjust selection if needed
    if state.selected_entry_idx > #buffer_history.entries then
      state.selected_entry_idx = math.max(1, #buffer_history.entries)
    end

    vim.notify("History entry deleted", vim.log.levels.INFO)
    UiHistory._render_all()
  elseif state.active_panel == "buffers" then
    -- Confirm and delete entire buffer history
    local count = #buffer_history.entries
    vim.ui.input({
      prompt = string.format("Delete buffer '%s' with %d entries? (y/N): ", buffer_history.buffer_name, count)
    }, function(input)
      if input and input:lower() == "y" then
        QueryHistory.clear_buffer_history(buffer_history.buffer_id)

        -- Refresh buffer list
        state.buffer_histories = QueryHistory.get_all_buffer_histories()

        if #state.buffer_histories == 0 then
          UiHistory._close()
          vim.notify("All history cleared", vim.log.levels.INFO)
        else
          if state.selected_buffer_idx > #state.buffer_histories then
            state.selected_buffer_idx = #state.buffer_histories
          end
          state.selected_entry_idx = 1
          UiHistory._render_all()
        end
      end
    end)
  end
end

---Clear all history
function UiHistory._clear_all()
  local stats = QueryHistory.get_stats()
  vim.ui.input({
    prompt = string.format("Clear ALL history (%d buffers, %d entries)? (y/N): ",
      stats.total_buffers, stats.total_entries)
  }, function(input)
    if input and input:lower() == "y" then
      QueryHistory.clear_all()
      UiHistory._close()
    end
  end)
end

---Export history
function UiHistory._export()
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
function UiHistory._search()
  vim.ui.input({ prompt = "Search query: " }, function(pattern)
    if not pattern or pattern == "" then
      return
    end

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

    -- Show results using vim.ui.select
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
        -- Close history window and load query
        UiHistory._close()

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

return UiHistory
