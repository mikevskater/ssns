---@class UiFloatInteractive
---Reusable interactive floating picker system
---Provides state management, navigation, and common keymaps for interactive list pickers
local UiFloatInteractive = {}

local UiFloatBase = require('ssns.ui.base.float_base')
local KeymapManager = require('ssns.keymap_manager')

---@class FloatInteractiveConfig
---@field title string Window title
---@field footer string? Footer text (default: "<CR> Select | <Esc> Cancel | j/k Navigate")
---@field width number? Window width (default: 60)
---@field height number? Window height (default: 20)
---@field on_render fun(state: FloatInteractiveState): string[] Function to render current content
---@field on_select fun(state: FloatInteractiveState) Function called when item is selected
---@field on_navigate fun(state: FloatInteractiveState, direction: string)? Called after navigation (optional)
---@field on_close fun(state: FloatInteractiveState)? Called when picker closes (optional)
---@field custom_keymaps table<string, fun(state: FloatInteractiveState)>? Additional keymaps
---@field initial_data any? Initial state data (accessible as state.data)

---@class FloatInteractiveState
---@field bufnr number Buffer number
---@field winid number Window ID
---@field selected_idx number Currently selected item index
---@field data any Custom data provided by caller
---@field config FloatInteractiveConfig Configuration
---@field total_items number Total number of items

---Create a new interactive floating picker
---@param config FloatInteractiveConfig Configuration
---@return FloatInteractiveState? state The state object (nil if creation failed)
function UiFloatInteractive.create(config)
  -- Validate config
  if not config.on_render or not config.on_select then
    vim.notify("SSNS: on_render and on_select are required", vim.log.levels.ERROR)
    return nil
  end

  -- Create buffer using base
  local bufnr = UiFloatBase.create_buffer({})
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'ssns-picker')

  -- Create window using base
  local winid = UiFloatBase.create_window(bufnr, {
    width = config.width or 60,
    height = config.height or 20,
    title = config.title,
    footer = config.footer or "<CR> Select | <Esc> Cancel | j/k Navigate",
    border = 'rounded',
    enter = true,
    zindex = 50,
  })

  -- Create state
  local state = {
    bufnr = bufnr,
    winid = winid,
    selected_idx = 1,
    data = config.initial_data,
    config = config,
    total_items = 0,
  }

  -- Initial render
  UiFloatInteractive.render(state)

  -- Setup keymaps
  UiFloatInteractive.setup_keymaps(state)

  -- Enable cursorline with themed highlighting
  vim.api.nvim_set_option_value('cursorline', true, { win = state.winid })
  vim.api.nvim_set_option_value('winhighlight', 'CursorLine:SsnsFloatSelected', { win = state.winid })

  return state
end

---Render the picker content
---@param state FloatInteractiveState
function UiFloatInteractive.render(state)
  if not state or not vim.api.nvim_buf_is_valid(state.bufnr) then
    return
  end

  -- Get lines from render callback
  local lines = state.config.on_render(state)
  state.total_items = #lines

  -- Clamp selected_idx
  if state.selected_idx < 1 then
    state.selected_idx = 1
  elseif state.selected_idx > state.total_items then
    state.selected_idx = state.total_items
  end

  -- Write to buffer using base
  UiFloatBase.set_buffer_lines(state.bufnr, lines)

  -- Position cursor using base
  if state.total_items > 0 then
    UiFloatBase.set_cursor(state.winid, state.selected_idx, 0)
  end
end

---Navigate up/down in the list
---@param state FloatInteractiveState
---@param direction string "up" or "down"
function UiFloatInteractive.navigate(state, direction)
  if not state or state.total_items == 0 then
    return
  end

  if direction == "up" then
    state.selected_idx = state.selected_idx - 1
    if state.selected_idx < 1 then
      state.selected_idx = state.total_items  -- Wrap to bottom
    end
  elseif direction == "down" then
    state.selected_idx = state.selected_idx + 1
    if state.selected_idx > state.total_items then
      state.selected_idx = 1  -- Wrap to top
    end
  end

  -- Re-render to update selection indicator
  UiFloatInteractive.render(state)

  -- Call navigation callback if provided
  if state.config.on_navigate then
    state.config.on_navigate(state, direction)
  end
end

---Close the picker
---@param state FloatInteractiveState
function UiFloatInteractive.close(state)
  if not state then return end

  -- Call close callback if provided
  if state.config.on_close then
    state.config.on_close(state)
  end

  -- Close window and delete buffer using base
  UiFloatBase.close_window(state.winid)
  UiFloatBase.delete_buffer(state.bufnr)
end

---Setup keymaps for the picker
---@param state FloatInteractiveState
function UiFloatInteractive.setup_keymaps(state)
  if not state or not vim.api.nvim_buf_is_valid(state.bufnr) then
    return
  end

  local function safe_call(fn)
    return function()
      if state and vim.api.nvim_buf_is_valid(state.bufnr) then
        fn()
      end
    end
  end

  -- Navigation
  KeymapManager.set_keymap(state.bufnr, 'n', 'j', safe_call(function()
    UiFloatInteractive.navigate(state, 'down')
  end), { noremap = true, silent = true }, 'ssns-picker')

  KeymapManager.set_keymap(state.bufnr, 'n', 'k', safe_call(function()
    UiFloatInteractive.navigate(state, 'up')
  end), { noremap = true, silent = true }, 'ssns-picker')

  KeymapManager.set_keymap(state.bufnr, 'n', '<Down>', safe_call(function()
    UiFloatInteractive.navigate(state, 'down')
  end), { noremap = true, silent = true }, 'ssns-picker')

  KeymapManager.set_keymap(state.bufnr, 'n', '<Up>', safe_call(function()
    UiFloatInteractive.navigate(state, 'up')
  end), { noremap = true, silent = true }, 'ssns-picker')

  -- Selection
  KeymapManager.set_keymap(state.bufnr, 'n', '<CR>', safe_call(function()
    state.config.on_select(state)
  end), { noremap = true, silent = true }, 'ssns-picker')

  -- Close
  KeymapManager.set_keymap(state.bufnr, 'n', '<Esc>', safe_call(function()
    UiFloatInteractive.close(state)
  end), { noremap = true, silent = true }, 'ssns-picker')

  KeymapManager.set_keymap(state.bufnr, 'n', 'q', safe_call(function()
    UiFloatInteractive.close(state)
  end), { noremap = true, silent = true }, 'ssns-picker')

  -- Custom keymaps
  if state.config.custom_keymaps then
    for key, handler in pairs(state.config.custom_keymaps) do
      KeymapManager.set_keymap(state.bufnr, 'n', key, safe_call(function()
        handler(state)
      end), { noremap = true, silent = true }, 'ssns-picker')
    end
  end
end

---Update window title dynamically
---@param state FloatInteractiveState
---@param title string New title
function UiFloatInteractive.update_title(state, title)
  UiFloatBase.update_title(state.winid, title)
end

---Update window footer dynamically
---@param state FloatInteractiveState
---@param footer string New footer
function UiFloatInteractive.update_footer(state, footer)
  UiFloatBase.update_footer(state.winid, footer)
end

---Helper: Add selection indicator to line
---@param line string Line content
---@param is_selected boolean Whether this line is selected
---@return string line Line with indicator
function UiFloatInteractive.add_indicator(line, is_selected)
  if is_selected then
    return "▶ " .. line
  else
    return "  " .. line
  end
end

return UiFloatInteractive
