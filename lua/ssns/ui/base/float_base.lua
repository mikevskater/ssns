---@class UiFloatBase
---Base class for floating window UIs
---Provides common functionality for window/buffer management, keymaps, and lifecycle
local UiFloatBase = {}

local KeymapManager = require('ssns.keymap_manager')

---@class FloatBaseConfig
---@field width number? Window width (default: 60)
---@field height number? Window height (default: 20)
---@field title string? Window title
---@field footer string? Footer text
---@field border string? Border style (default: "rounded")
---@field enter boolean? Focus window on creation (default: true)
---@field zindex number? Window z-index (default: 50)

---@class FloatBaseState
---@field bufnr number Buffer number
---@field winid number Window ID
---@field config FloatBaseConfig Configuration
---@field namespace number Highlight namespace

---Create a floating window buffer
---@param config FloatBaseConfig Configuration
---@return number bufnr Buffer number
function UiFloatBase.create_buffer(config)
  local bufnr = vim.api.nvim_create_buf(false, true)
  
  -- Configure buffer
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
  
  return bufnr
end

---Calculate centered window position
---@param width number Window width
---@param height number Window height
---@return number row Row position
---@return number col Column position
function UiFloatBase.calculate_centered_position(width, height)
  local ui = vim.api.nvim_list_uis()[1]
  local win_width = ui.width
  local win_height = ui.height
  
  local row = math.floor((win_height - height) / 2)
  local col = math.floor((win_width - width) / 2)
  
  return row, col
end

---Create a floating window
---@param bufnr number Buffer number
---@param config FloatBaseConfig Configuration
---@return number winid Window ID
function UiFloatBase.create_window(bufnr, config)
  local width = config.width or 60
  local height = config.height or 20
  local row, col = UiFloatBase.calculate_centered_position(width, height)
  
  local win_config = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = config.border or 'rounded',
    zindex = config.zindex or 50,
  }
  
  if config.title then
    win_config.title = config.title
    win_config.title_pos = 'center'
  end
  
  if config.footer then
    win_config.footer = config.footer
    win_config.footer_pos = 'center'
  end
  
  -- Build winhighlight string (to be applied after window creation)
  local winhl = {'Normal:Normal', 'CursorLine:SsnsFloatSelected'}
  if not config.no_border_hl then
    table.insert(winhl, 'FloatBorder:SsnsFloatBorder')
  end
  if not config.no_title_hl then
    table.insert(winhl, 'FloatTitle:SsnsFloatTitle')
  end
  local winhighlight = table.concat(winhl, ',')
  
  local enter = config.enter ~= nil and config.enter or true
  local winid = vim.api.nvim_open_win(bufnr, enter, win_config)
  
  -- Apply winhighlight after window creation
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_set_option(winid, 'winhighlight', winhighlight)
  end
  
  return winid
end

---Set buffer content
---@param bufnr number Buffer number
---@param lines string[] Lines to set
function UiFloatBase.set_buffer_lines(bufnr, lines)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
end

---Update window title
---@param winid number Window ID
---@param title string New title
function UiFloatBase.update_title(winid, title)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end
  
  local current_config = vim.api.nvim_win_get_config(winid)
  current_config.title = title
  vim.api.nvim_win_set_config(winid, current_config)
end

---Update window footer
---@param winid number Window ID
---@param footer string New footer
function UiFloatBase.update_footer(winid, footer)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end
  
  local current_config = vim.api.nvim_win_get_config(winid)
  current_config.footer = footer
  vim.api.nvim_win_set_config(winid, current_config)
end

---Set window options
---@param winid number Window ID
---@param options table Window options
function UiFloatBase.set_window_options(winid, options)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end
  
  for option, value in pairs(options) do
    vim.api.nvim_set_option_value(option, value, { win = winid })
  end
end

---Close a window safely
---@param winid number Window ID
function UiFloatBase.close_window(winid)
  if winid and vim.api.nvim_win_is_valid(winid) then
    pcall(vim.api.nvim_win_close, winid, true)
  end
end

---Delete a buffer safely
---@param bufnr number Buffer number
function UiFloatBase.delete_buffer(bufnr)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
end

---Create a highlight namespace
---@param name string Namespace name
---@return number ns_id Namespace ID
function UiFloatBase.create_namespace(name)
  return vim.api.nvim_create_namespace(name)
end

---Clear highlights in namespace
---@param bufnr number Buffer number
---@param ns_id number Namespace ID
function UiFloatBase.clear_highlights(bufnr, ns_id)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  end
end

---Add highlight to buffer line
---@param bufnr number Buffer number
---@param ns_id number Namespace ID
---@param hl_group string Highlight group
---@param line number Line number (0-indexed)
---@param col_start number Start column (0-indexed)
---@param col_end number End column (-1 for end of line)
function UiFloatBase.add_highlight(bufnr, ns_id, hl_group, line, col_start, col_end)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl_group, line, col_start, col_end)
  end
end

---Set cursor position
---@param winid number Window ID
---@param line number Line number (1-indexed)
---@param col number Column number (0-indexed)
function UiFloatBase.set_cursor(winid, line, col)
  if vim.api.nvim_win_is_valid(winid) then
    pcall(vim.api.nvim_win_set_cursor, winid, {line, col or 0})
  end
end

---Setup keymap on buffer
---@param bufnr number Buffer number
---@param mode string Mode (e.g., "n", "i")
---@param lhs string Key to map
---@param rhs function|string Handler function or command
---@param opts table? Options
---@param group string? Keymap group name
function UiFloatBase.set_keymap(bufnr, mode, lhs, rhs, opts, group)
  opts = opts or { noremap = true, silent = true }
  KeymapManager.set(bufnr, mode, lhs, rhs, opts, false)
  if group then
    KeymapManager.mark_group_active(bufnr, group or 'float_ui')
  end
end

---Setup multiple keymaps on buffer
---@param bufnr number Buffer number
---@param keymaps table[] Array of keymap definitions
---@param group string? Keymap group name
function UiFloatBase.set_keymaps(bufnr, keymaps, group)
  for _, keymap in ipairs(keymaps) do
    local mode = keymap.mode or 'n'
    local opts = { noremap = true, silent = true, desc = keymap.desc }
    UiFloatBase.set_keymap(bufnr, mode, keymap.lhs, keymap.rhs, opts, group)
  end
end

---Create autocmd for window cleanup
---@param winid number Window ID
---@param callback function Cleanup callback
---@return number augroup_id Autocmd group ID
function UiFloatBase.setup_cleanup_autocmd(winid, callback)
  local group_name = string.format("FloatCleanup_%d", winid)
  local group = vim.api.nvim_create_augroup(group_name, { clear = true })
  
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(winid),
    once = true,
    callback = callback,
  })
  
  return group
end

---Safe wrapper for callbacks
---@param callback function Callback to wrap
---@param state table? State object to validate
---@return function wrapped Wrapped callback
function UiFloatBase.safe_callback(callback, state)
  return function(...)
    if state then
      -- Validate state if provided
      if state.bufnr and not vim.api.nvim_buf_is_valid(state.bufnr) then
        return
      end
      if state.winid and not vim.api.nvim_win_is_valid(state.winid) then
        return
      end
    end
    
    local ok, err = pcall(callback, ...)
    if not ok then
      vim.notify(string.format("SSNS Float UI Error: %s", err), vim.log.levels.ERROR)
    end
  end
end

---Helper: Calculate layout for split panels
---@param total_width number Total width available
---@param total_height number Total height available
---@param ratios number[] Width ratios for each panel (e.g., {0.3, 0.7})
---@return table[] layouts Array of layout configs
function UiFloatBase.calculate_split_layout(total_width, total_height, ratios)
  local layouts = {}
  local ui = vim.api.nvim_list_uis()[1]
  local screen_width = ui.width
  local screen_height = ui.height
  
  local start_row = math.floor((screen_height - total_height) / 2)
  local start_col = math.floor((screen_width - total_width) / 2)
  
  -- Calculate actual usable width (accounting for borders)
  -- Each panel has left border (1 char), and the last panel has right border (1 char)
  -- Shared borders are counted once
  local num_panels = #ratios
  local border_chars = num_panels + 1  -- num_panels left borders + 1 right border for last
  local usable_width = total_width - border_chars
  
  local current_col = start_col
  
  for i, ratio in ipairs(ratios) do
    local panel_width = math.floor(usable_width * ratio)
    
    -- Account for inner content width (subtract 2 for left/right borders)
    local content_width = panel_width
    
    table.insert(layouts, {
      width = content_width,
      height = total_height - 2,  -- Subtract for top/bottom borders
      row = start_row,
      col = current_col,
    })
    
    -- Move to next panel position (content + 1 for shared border)
    current_col = current_col + content_width + 1
  end
  
  return layouts
end

---Helper: Create custom split borders
---@param is_first boolean Is this the first panel
---@param is_last boolean Is this the last panel
---@return table border Border characters
function UiFloatBase.create_split_border(is_first, is_last)
  local chars = {
    horizontal = "─",
    vertical = "│",
    top_left = "╭",
    top_right = "╮",
    bottom_left = "╰",
    bottom_right = "╯",
    t_down = "┬",
    t_up = "┴",
  }
  
  if is_first and is_last then
    -- Single panel - regular border
    return {
      chars.top_left, chars.horizontal, chars.top_right,
      chars.vertical, chars.bottom_right, chars.horizontal,
      chars.bottom_left, chars.vertical,
    }
  elseif is_first then
    -- First panel - right side connects to next
    return {
      chars.top_left, chars.horizontal, chars.t_down,
      chars.vertical, chars.t_up, chars.horizontal,
      chars.bottom_left, chars.vertical,
    }
  elseif is_last then
    -- Last panel - left side connects to previous
    return {
      chars.t_down, chars.horizontal, chars.top_right,
      chars.vertical, chars.bottom_right, chars.horizontal,
      chars.t_up, chars.vertical,
    }
  else
    -- Middle panel - both sides connect
    return {
      chars.t_down, chars.horizontal, chars.t_down,
      chars.vertical, chars.t_up, chars.horizontal,
      chars.t_up, chars.vertical,
    }
  end
end

return UiFloatBase
