---@class InputManager
---Manages input fields within floating windows
---Handles input mode, Tab navigation, and value extraction
local InputManager = {}
InputManager.__index = InputManager

---@class InputManagerConfig
---@field bufnr number Buffer number to manage
---@field winid number Window ID
---@field inputs table<string, InputField> Map of input key -> field info
---@field input_order string[] Ordered list of input keys
---@field dropdowns table<string, DropdownField>? Map of dropdown key -> field info
---@field dropdown_order string[]? Ordered list of dropdown keys
---@field on_value_change fun(key: string, value: string)? Called when input value changes
---@field on_input_enter fun(key: string)? Called when entering input mode
---@field on_input_exit fun(key: string)? Called when exiting input mode
---@field on_dropdown_change fun(key: string, value: string)? Called when dropdown value changes

---@class InputField (from content_builder)
---@field key string Unique identifier for the input
---@field line number 1-indexed line number
---@field col_start number 0-indexed start column of input value area
---@field col_end number 0-indexed end column of input value area (dynamic, updates based on content)
---@field width number Current effective width of input field
---@field default_width number Default/minimum display width (pads with spaces, expands if text longer)
---@field min_width number? Minimum display width override
---@field value string Current value
---@field default string Default/initial value
---@field placeholder string Placeholder text when empty
---@field is_showing_placeholder boolean Whether currently displaying placeholder text
---@field prefix_len number? Length of label prefix (for line reconstruction)

---@class InputManagerState
---@field in_input_mode boolean Whether currently in input mode
---@field active_input string? Key of currently active input
---@field values table<string, string> Current input values
---@field original_keymaps table Stored original keymaps

---Create a new InputManager
---@param config InputManagerConfig
---@return InputManager
function InputManager.new(config)
  local self = setmetatable({}, InputManager)

  self.bufnr = config.bufnr
  self.winid = config.winid
  self.inputs = config.inputs or {}
  self.input_order = config.input_order or {}
  self.dropdowns = config.dropdowns or {}
  self.dropdown_order = config.dropdown_order or {}
  self.on_value_change = config.on_value_change
  self.on_input_enter = config.on_input_enter
  self.on_input_exit = config.on_input_exit
  self.on_dropdown_change = config.on_dropdown_change

  -- Build combined field order (inputs and dropdowns interleaved by line number)
  self._all_fields = {}  -- Array of { type = "input"|"dropdown", key = string, line = number }
  self._field_order = {}  -- Ordered keys for navigation

  -- State
  self.in_input_mode = false
  self.active_input = nil
  self.current_field_idx = 1  -- Track current field index for Tab navigation
  self.values = {}
  self.dropdown_values = {}
  self._namespace = vim.api.nvim_create_namespace("ssns_input_manager")
  self._autocmd_group = nil

  -- Dropdown state
  self._dropdown_open = false
  self._dropdown_key = nil
  self._dropdown_float = nil  -- FloatWindow instance
  self._dropdown_ns = nil     -- Highlight namespace for dropdown content
  self._dropdown_selected_idx = 1
  self._dropdown_original_value = nil
  self._dropdown_filtered_options = nil
  self._dropdown_filter_text = ""
  self._dropdown_autocmd_group = nil

  -- Initialize values from input definitions and track placeholder state
  for key, input in pairs(self.inputs) do
    self.values[key] = input.value or ""
    -- Track if this input is showing placeholder
    input.is_showing_placeholder = (self.values[key] == "" and (input.placeholder or "") ~= "")
  end

  -- Initialize dropdown values
  for key, dropdown in pairs(self.dropdowns) do
    self.dropdown_values[key] = dropdown.value or ""
  end

  -- Build combined field order sorted by line number
  self:_build_field_order()

  return self
end

---Build combined field order sorted by line number
function InputManager:_build_field_order()
  self._all_fields = {}

  -- Add inputs
  for _, key in ipairs(self.input_order) do
    local input = self.inputs[key]
    if input then
      table.insert(self._all_fields, {
        type = "input",
        key = key,
        line = input.line,
      })
    end
  end

  -- Add dropdowns
  for _, key in ipairs(self.dropdown_order) do
    local dropdown = self.dropdowns[key]
    if dropdown then
      table.insert(self._all_fields, {
        type = "dropdown",
        key = key,
        line = dropdown.line,
      })
    end
  end

  -- Sort by line number
  table.sort(self._all_fields, function(a, b)
    return a.line < b.line
  end)

  -- Build ordered key list
  self._field_order = {}
  for _, field in ipairs(self._all_fields) do
    table.insert(self._field_order, field.key)
  end
end

---Get field info by key (input or dropdown)
---@param key string Field key
---@return table? field_info { type = "input"|"dropdown", field = InputField|DropdownField }
function InputManager:_get_field(key)
  if self.inputs[key] then
    return { type = "input", field = self.inputs[key] }
  elseif self.dropdowns[key] then
    return { type = "dropdown", field = self.dropdowns[key] }
  end
  return nil
end

---Setup input mode handling for the buffer
function InputManager:setup()
  -- Create autocmd group for this manager
  self._autocmd_group = vim.api.nvim_create_augroup(
    "SSNSInputManager_" .. self.bufnr, 
    { clear = true }
  )
  
  -- Setup cursor movement detection to enter input mode
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = self._autocmd_group,
    buffer = self.bufnr,
    callback = function()
      if not self.in_input_mode then
        self:_check_cursor_on_input()
      end
    end,
  })
  
  -- Handle InsertLeave to exit input mode properly
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = self._autocmd_group,
    buffer = self.bufnr,
    callback = function()
      if self.in_input_mode then
        self:_exit_input_mode()
      end
    end,
  })
  
  -- Handle text changes in insert mode - sync value and adjust width in real-time
  vim.api.nvim_create_autocmd("TextChangedI", {
    group = self._autocmd_group,
    buffer = self.bufnr,
    callback = function()
      if self.in_input_mode and self.active_input then
        self:_sync_input_value()
        -- Re-render to adjust width in real-time as user types
        self:_render_input_realtime(self.active_input)
      end
    end,
  })
  
  -- Setup Tab/Shift-Tab for input navigation
  self:_setup_input_keymaps()
end

---Check if cursor is on an input field and update highlighting
function InputManager:_check_cursor_on_input()
  local cursor = vim.api.nvim_win_get_cursor(self.winid)
  local row = cursor[1]  -- 1-indexed
  local col = cursor[2]  -- 0-indexed
  
  -- Find input at cursor position
  for i, key in ipairs(self.input_order) do
    local input = self.inputs[key]
    if input and input.line == row and col >= input.col_start and col < input.col_end then
      -- Cursor is on this input - update index and highlight
      self.current_input_idx = i
      self:_highlight_current_input(key)
      return
    end
  end
  
  -- Not on any input - keep current input highlighted
  if #self.input_order > 0 then
    local current_key = self.input_order[self.current_input_idx]
    self:_highlight_current_input(current_key)
  end
end

---Enter input mode for a specific input field
---@param key string Input key to activate
function InputManager:enter_input_mode(key)
  local input = self.inputs[key]
  if not input then return end
  
  self.in_input_mode = true
  self.active_input = key
  
  -- Update current_input_idx to match activated input
  for i, k in ipairs(self.input_order) do
    if k == key then
      self.current_input_idx = i
      break
    end
  end
  
  -- Make buffer modifiable
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', true)

  -- Disable autocompletion in input buffer
  vim.b[self.bufnr].cmp_enabled = false      -- nvim-cmp
  vim.b[self.bufnr].blink_cmp_enable = false -- blink.cmp
  vim.b[self.bufnr].completion = false       -- generic

  -- If showing placeholder, clear it to blank spaces for editing
  local value = self.values[key] or ""
  if input.is_showing_placeholder then
    -- Clear the placeholder - replace with spaces
    self:_clear_input_to_spaces(key)
    value = ""
    self.values[key] = ""
    input.is_showing_placeholder = false
  end
  
  -- Position cursor at end of current value (or start if empty)
  local cursor_col = input.col_start + #value
  cursor_col = math.min(cursor_col, input.col_end - 1)
  
  vim.api.nvim_win_set_cursor(self.winid, {input.line, cursor_col})
  
  -- Highlight active input
  self:_highlight_current_input(key)
  
  -- Enter insert mode
  vim.cmd("startinsert")
  
  -- Callback
  if self.on_input_enter then
    self.on_input_enter(key)
  end
end

---Exit input mode
function InputManager:_exit_input_mode()
  if not self.in_input_mode then return end
  
  local exited_key = self.active_input
  
  -- Sync final value
  self:_sync_input_value()
  
  self.in_input_mode = false
  self.active_input = nil
  
  -- Always re-render to normalize width (removes extra spaces, restores placeholder if empty)
  if exited_key then
    local input = self.inputs[exited_key]
    local value = self.values[exited_key] or ""
    if input then
      -- Track placeholder state
      if value == "" and (input.placeholder or "") ~= "" then
        input.is_showing_placeholder = true
      else
        input.is_showing_placeholder = false
      end
      -- Re-render to normalize display width
      self:_render_input(exited_key)
    end
  end
  
  -- Make buffer non-modifiable again
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', false)
  
  -- Keep the current input highlighted (not all cleared)
  if exited_key then
    self:_highlight_current_input(exited_key)
  end
  
  -- Callback
  if self.on_input_exit and exited_key then
    self.on_input_exit(exited_key)
  end
end

---Clear an input field to blank spaces (for placeholder clearing)
---Resets to default_width when clearing
---@param key string Input key
function InputManager:_clear_input_to_spaces(key)
  local input = self.inputs[key]
  if not input then return end
  
  local default_width = input.default_width or input.width or 20
  local min_width = input.min_width or default_width
  local effective_width = math.max(default_width, min_width)
  
  -- Replace with spaces at default width
  local blank_text = string.rep(" ", effective_width)
  
  -- Get current line
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, input.line - 1, input.line, false)
  if #lines == 0 then return end
  
  local line = lines[1]
  
  -- Find the actual closing bracket position
  local bracket_pos = line:find("%]", input.col_start + 1)
  if not bracket_pos then return end
  
  -- Reconstruct line with blank content at default width
  local before = line:sub(1, input.col_start)  -- Up to and including "["
  local after = line:sub(bracket_pos + 1)  -- Everything after "]"
  
  -- Build new line and update col_end
  local new_line = before .. blank_text .. "]" .. after
  input.col_end = input.col_start + effective_width
  input.width = effective_width
  
  -- Update buffer (already modifiable when entering input mode)
  vim.api.nvim_buf_set_lines(self.bufnr, input.line - 1, input.line, false, {new_line})
end

---Sync the current input's value from the buffer
function InputManager:_sync_input_value()
  if not self.active_input then return end
  
  local input = self.inputs[self.active_input]
  if not input then return end
  
  -- Read the line from buffer
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, input.line - 1, input.line, false)
  if #lines == 0 then return end
  
  local line_text = lines[1]
  
  -- Find the closing bracket to determine actual input end
  -- Start searching from col_start
  local bracket_pos = line_text:find("%]", input.col_start + 1)
  local actual_col_end = bracket_pos and (bracket_pos - 1) or input.col_end
  
  -- Extract value from input area (between col_start and closing bracket)
  local raw_value = line_text:sub(input.col_start + 1, actual_col_end)
  
  -- Trim trailing spaces (but preserve leading spaces if user wants them)
  local value = raw_value:gsub("%s+$", "")
  
  -- Update stored value and col_end
  local old_value = self.values[self.active_input]
  self.values[self.active_input] = value
  
  -- Update col_end based on new content
  local default_width = input.default_width or input.width or 20
  local min_width = input.min_width or default_width
  local effective_width = math.max(default_width, min_width, #value)
  input.col_end = input.col_start + effective_width
  input.width = effective_width
  
  -- Callback if changed
  if self.on_value_change and value ~= old_value then
    self.on_value_change(self.active_input, value)
  end
end

---Navigate to next field (input or dropdown)
function InputManager:next_input()
  if #self._field_order == 0 then return end

  -- Find next field index
  local next_idx = (self.current_field_idx % #self._field_order) + 1
  local next_key = self._field_order[next_idx]

  -- Update tracked index
  self.current_field_idx = next_idx

  -- Exit current input mode if active
  if self.in_input_mode then
    -- Stop insert mode, then move to next
    vim.cmd("stopinsert")
    vim.schedule(function()
      self:_focus_field(next_key)
    end)
  else
    self:_focus_field(next_key)
  end
end

---Navigate to previous field (input or dropdown)
function InputManager:prev_input()
  if #self._field_order == 0 then return end

  -- Find previous field index
  local prev_idx = ((self.current_field_idx - 2) % #self._field_order) + 1
  local prev_key = self._field_order[prev_idx]

  -- Update tracked index
  self.current_field_idx = prev_idx

  -- Exit current input mode if active
  if self.in_input_mode then
    vim.cmd("stopinsert")
    vim.schedule(function()
      self:_focus_field(prev_key)
    end)
  else
    self:_focus_field(prev_key)
  end
end

---Focus a field (input or dropdown) without activating it
---@param key string Field key
function InputManager:_focus_field(key)
  local field_info = self:_get_field(key)
  if not field_info then return end

  local field = field_info.field
  vim.api.nvim_win_set_cursor(self.winid, {field.line, field.col_start})
  self:_highlight_current_field(key)
end

---Activate a field (enter input mode or open dropdown)
---@param key string Field key
function InputManager:_activate_field(key)
  local field_info = self:_get_field(key)
  if not field_info then return end

  if field_info.type == "input" then
    self:enter_input_mode(key)
  elseif field_info.type == "dropdown" then
    self:_open_dropdown(key)
  end
end

---Setup keymaps for input navigation
function InputManager:_setup_input_keymaps()
  local opts = { buffer = self.bufnr, noremap = true, silent = true }

  -- Normal mode: Enter activates field under cursor (or at current index)
  vim.keymap.set('n', '<CR>', function()
    local cursor = vim.api.nvim_win_get_cursor(self.winid)
    local row = cursor[1]
    local col = cursor[2]

    -- First check if cursor is directly on an input
    for key, input in pairs(self.inputs) do
      if input.line == row and col >= input.col_start and col < input.col_end then
        self:enter_input_mode(key)
        return
      end
    end

    -- Check if cursor is directly on a dropdown
    for key, dropdown in pairs(self.dropdowns) do
      if dropdown.line == row and col >= dropdown.col_start and col < dropdown.col_end then
        self:_open_dropdown(key)
        return
      end
    end

    -- Otherwise, activate the current tracked field
    if #self._field_order > 0 then
      local current_key = self._field_order[self.current_field_idx]
      if current_key then
        self:_activate_field(current_key)
      end
    end
  end, opts)
  
  -- Normal mode: j/Down moves to next input
  vim.keymap.set('n', 'j', function()
    self:next_input()
  end, opts)
  
  vim.keymap.set('n', '<Down>', function()
    self:next_input()
  end, opts)
  
  -- Normal mode: k/Up moves to previous input
  vim.keymap.set('n', 'k', function()
    self:prev_input()
  end, opts)
  
  vim.keymap.set('n', '<Up>', function()
    self:prev_input()
  end, opts)
  
  -- Normal mode Tab/Shift-Tab: also move between inputs (alternative)
  vim.keymap.set('n', '<Tab>', function()
    self:next_input()
  end, opts)
  
  vim.keymap.set('n', '<S-Tab>', function()
    self:prev_input()
  end, opts)
  
  -- Insert mode Enter: confirm/exit input (instead of newline)
  vim.keymap.set('i', '<CR>', function()
    vim.cmd("stopinsert")
    -- Call on_submit callback if set (after a short delay to let stopinsert complete)
    vim.schedule(function()
      if self.on_submit then
        self.on_submit()
      end
    end)
  end, opts)
  
  -- Insert mode Tab/Shift-Tab: move to next/prev input
  vim.keymap.set('i', '<Tab>', function()
    self:next_input()
  end, opts)
  
  vim.keymap.set('i', '<S-Tab>', function()
    self:prev_input()
  end, opts)
  
  -- Insert mode Escape: exit input mode
  vim.keymap.set('i', '<Esc>', function()
    vim.cmd("stopinsert")
  end, opts)
  
  -- Prevent cursor from leaving input bounds in insert mode
  vim.keymap.set('i', '<Left>', function()
    local cursor = vim.api.nvim_win_get_cursor(self.winid)
    local input = self.inputs[self.active_input]
    if input and cursor[2] > input.col_start then
      vim.api.nvim_win_set_cursor(self.winid, {cursor[1], cursor[2] - 1})
    end
  end, opts)
  
  vim.keymap.set('i', '<Right>', function()
    local cursor = vim.api.nvim_win_get_cursor(self.winid)
    local input = self.inputs[self.active_input]
    if input then
      local value = self.values[self.active_input] or ""
      local max_col = input.col_start + #value
      -- Allow cursor to move up to end of actual value (not padded spaces)
      if cursor[2] < max_col then
        vim.api.nvim_win_set_cursor(self.winid, {cursor[1], cursor[2] + 1})
      end
    end
  end, opts)
  
  -- Prevent Home/End from going outside input
  vim.keymap.set('i', '<Home>', function()
    local input = self.inputs[self.active_input]
    if input then
      vim.api.nvim_win_set_cursor(self.winid, {input.line, input.col_start})
    end
  end, opts)
  
  vim.keymap.set('i', '<End>', function()
    local input = self.inputs[self.active_input]
    if input then
      local value = self.values[self.active_input] or ""
      vim.api.nvim_win_set_cursor(self.winid, {input.line, input.col_start + #value})
    end
  end, opts)
  
  -- Handle backspace at start of input
  vim.keymap.set('i', '<BS>', function()
    local cursor = vim.api.nvim_win_get_cursor(self.winid)
    local input = self.inputs[self.active_input]
    if input and cursor[2] > input.col_start then
      -- Normal backspace
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<BS>', true, false, true), 'n', false)
    end
    -- Don't do anything if at start of input
  end, opts)
end

---Highlight an input field
---@param key string Input key
---@param active boolean Whether input is active/focused
function InputManager:_highlight_input(key, active)
  local input = self.inputs[key]
  if not input then return end
  
  -- Clear existing highlights first
  vim.api.nvim_buf_clear_namespace(self.bufnr, self._namespace, input.line - 1, input.line)
  
  -- Determine highlight group based on state
  local hl_group
  if active then
    hl_group = "SsnsFloatInputActive"
  elseif input.is_showing_placeholder then
    hl_group = "SsnsFloatInputPlaceholder"
  else
    hl_group = "SsnsFloatInput"
  end
  
  vim.api.nvim_buf_add_highlight(
    self.bufnr, self._namespace, hl_group,
    input.line - 1, input.col_start, input.col_end
  )
end

---Highlight the current input (for Tab navigation in normal mode)
---@param current_key string Key of currently focused input
function InputManager:_highlight_current_input(current_key)
  -- Clear all and reapply with current highlighted
  vim.api.nvim_buf_clear_namespace(self.bufnr, self._namespace, 0, -1)
  
  for key, _ in pairs(self.inputs) do
    self:_highlight_input(key, key == current_key)
  end
end

---Clear all input highlights
function InputManager:_clear_input_highlights()
  vim.api.nvim_buf_clear_namespace(self.bufnr, self._namespace, 0, -1)
  
  -- Reapply inactive highlights to all inputs
  for key, _ in pairs(self.inputs) do
    self:_highlight_input(key, false)
  end
end

---Initialize highlights for all fields (inputs and dropdowns)
function InputManager:init_highlights()
  -- Highlight first field as current, others as inactive
  if #self._field_order > 0 then
    local first_key = self._field_order[1]
    self:_highlight_current_field(first_key)
  end
end

---Get the current value of an input
---@param key string Input key
---@return string? value
function InputManager:get_value(key)
  return self.values[key]
end

---Get all input values
---@return table<string, string> values Map of key -> value
function InputManager:get_all_values()
  return vim.deepcopy(self.values)
end

---Set the value of an input
---@param key string Input key
---@param value string New value
function InputManager:set_value(key, value)
  local input = self.inputs[key]
  if not input then return end
  
  self.values[key] = value or ""
  
  -- Update buffer content if buffer is valid
  if vim.api.nvim_buf_is_valid(self.bufnr) then
    self:_render_input(key)
  end
end

---Render an input field's value to the buffer (with dynamic width support)
---@param key string Input key
function InputManager:_render_input(key)
  local input = self.inputs[key]
  if not input then return end
  
  local value = self.values[key] or ""
  local placeholder = input.placeholder or ""
  local default_width = input.default_width or input.width or 20
  local min_width = input.min_width or default_width
  
  -- Determine display text and track placeholder state
  local display_text = value
  if value == "" and placeholder ~= "" then
    display_text = placeholder
    input.is_showing_placeholder = true
  else
    input.is_showing_placeholder = false
  end
  
  -- Calculate effective width: at least default_width, but expands for longer text
  local effective_width = math.max(default_width, min_width, #display_text)
  
  -- Pad to effective width (no truncation - expands if needed)
  if #display_text < effective_width then
    display_text = display_text .. string.rep(" ", effective_width - #display_text)
  end
  
  -- Get current line
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, input.line - 1, input.line, false)
  if #lines == 0 then return end
  
  local line = lines[1]
  
  -- Find the actual closing bracket position in the current line
  local bracket_pos = line:find("%]", input.col_start + 1)
  if not bracket_pos then
    -- No bracket found, something is wrong - just return
    return
  end
  
  -- Update input's col_end and width for dynamic sizing
  input.col_end = input.col_start + effective_width
  input.width = effective_width
  
  -- Reconstruct the line with new input content
  local before = line:sub(1, input.col_start)  -- Everything up to and including "["
  local after = line:sub(bracket_pos + 1)  -- Everything after the "]"
  
  -- Build new line: before + display_text + "]" + after
  local new_line = before .. display_text .. "]" .. after
  
  -- Update buffer
  local was_modifiable = vim.api.nvim_buf_get_option(self.bufnr, 'modifiable')
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(self.bufnr, input.line - 1, input.line, false, {new_line})
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', was_modifiable)
  
  -- Re-apply highlight for this input after width change
  local current_key = self.input_order[self.current_input_idx]
  self:_highlight_input(key, key == current_key)
end

---Render an input field in real-time while typing (preserves cursor position)
---@param key string Input key
function InputManager:_render_input_realtime(key)
  local input = self.inputs[key]
  if not input then return end
  
  local value = self.values[key] or ""
  local default_width = input.default_width or input.width or 20
  local min_width = input.min_width or default_width
  
  -- Calculate effective width: at least default_width, but expands for longer text
  local effective_width = math.max(default_width, min_width, #value)
  
  -- Pad value with spaces to effective width
  local display_text = value
  if #display_text < effective_width then
    display_text = display_text .. string.rep(" ", effective_width - #display_text)
  end
  
  -- Save cursor position (relative to input start)
  local cursor = vim.api.nvim_win_get_cursor(self.winid)
  local cursor_offset = cursor[2] - input.col_start
  
  -- Get current line
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, input.line - 1, input.line, false)
  if #lines == 0 then return end
  
  local line = lines[1]
  
  -- Find the actual closing bracket position in the current line
  local bracket_pos = line:find("%]", input.col_start + 1)
  if not bracket_pos then
    -- No bracket found, something is wrong - just return
    return
  end
  
  -- Update input's col_end and width for dynamic sizing
  input.col_end = input.col_start + effective_width
  input.width = effective_width
  
  -- Reconstruct the line with new input content
  local before = line:sub(1, input.col_start)  -- Everything up to and including "["
  local after = line:sub(bracket_pos + 1)  -- Everything after the "]"
  
  -- Build new line: before + display_text + "]" + after
  local new_line = before .. display_text .. "]" .. after
  
  -- Update buffer (already modifiable in insert mode)
  vim.api.nvim_buf_set_lines(self.bufnr, input.line - 1, input.line, false, {new_line})
  
  -- Restore cursor position
  local new_cursor_col = input.col_start + cursor_offset
  -- Clamp cursor to valid range (don't go past end of actual value)
  new_cursor_col = math.min(new_cursor_col, input.col_start + #value)
  new_cursor_col = math.max(new_cursor_col, input.col_start)
  vim.api.nvim_win_set_cursor(self.winid, {cursor[1], new_cursor_col})
  
  -- Re-apply highlight
  self:_highlight_input(key, true)
end

---Update input definitions (e.g., after re-render)
---@param inputs table<string, InputField> New input definitions
---@param input_order string[] New input order
---@param dropdowns table<string, DropdownField>? New dropdown definitions
---@param dropdown_order string[]? New dropdown order
function InputManager:update_inputs(inputs, input_order, dropdowns, dropdown_order)
  self.inputs = inputs or {}
  self.input_order = input_order or {}
  self.dropdowns = dropdowns or self.dropdowns or {}
  self.dropdown_order = dropdown_order or self.dropdown_order or {}

  -- Preserve existing values, add new ones, and track placeholder state
  for key, input in pairs(self.inputs) do
    if not self.values[key] then
      self.values[key] = input.value or ""
    end
    -- Update placeholder state based on current value
    local value = self.values[key] or ""
    input.is_showing_placeholder = (value == "" and (input.placeholder or "") ~= "")
  end

  -- Preserve dropdown values
  for key, dropdown in pairs(self.dropdowns) do
    if not self.dropdown_values[key] then
      self.dropdown_values[key] = dropdown.value or ""
    end
  end

  -- Rebuild field order
  self:_build_field_order()
end

---Highlight a field (input or dropdown)
---@param current_key string Key of currently focused field
function InputManager:_highlight_current_field(current_key)
  -- Clear all and reapply with current highlighted
  vim.api.nvim_buf_clear_namespace(self.bufnr, self._namespace, 0, -1)

  -- Highlight inputs
  for key, _ in pairs(self.inputs) do
    self:_highlight_input(key, key == current_key)
  end

  -- Highlight dropdowns
  for key, _ in pairs(self.dropdowns) do
    self:_highlight_dropdown(key, key == current_key)
  end
end

---Highlight a dropdown field
---@param key string Dropdown key
---@param active boolean Whether dropdown is active/focused
function InputManager:_highlight_dropdown(key, active)
  local dropdown = self.dropdowns[key]
  if not dropdown then return end

  -- Determine highlight group based on state
  local hl_group
  if active then
    hl_group = "SsnsFloatInputActive"
  elseif dropdown.is_placeholder then
    hl_group = "SsnsFloatInputPlaceholder"
  else
    hl_group = "SsnsFloatInput"
  end

  -- Highlight the dropdown value area (excluding arrow)
  local arrow_len = 4  -- " ▼" is 4 bytes
  vim.api.nvim_buf_add_highlight(
    self.bufnr, self._namespace, hl_group,
    dropdown.line - 1, dropdown.col_start, dropdown.col_end - arrow_len
  )

  -- Arrow always gets hint color
  vim.api.nvim_buf_add_highlight(
    self.bufnr, self._namespace, "SsnsUiHint",
    dropdown.line - 1, dropdown.col_end - arrow_len, dropdown.col_end
  )
end

---Open dropdown window for a dropdown field
---@param key string Dropdown key
function InputManager:_open_dropdown(key)
  local dropdown = self.dropdowns[key]
  if not dropdown then return end

  -- Store original value for cancel
  self._dropdown_original_value = self.dropdown_values[key]
  self._dropdown_key = key
  self._dropdown_open = true
  self._dropdown_filter_text = ""
  self._dropdown_filtered_options = vim.deepcopy(dropdown.options)

  -- Find index of currently selected value
  self._dropdown_selected_idx = 1
  for i, opt in ipairs(dropdown.options) do
    if opt.value == self._dropdown_original_value then
      self._dropdown_selected_idx = i
      break
    end
  end

  -- Calculate dropdown window position (below the dropdown field)
  local win_info = vim.fn.getwininfo(self.winid)[1]
  if not win_info then return end

  -- Get screen position of parent window
  local parent_row = win_info.winrow
  local parent_col = win_info.wincol

  -- Dropdown position: directly below the field, aligned with the "[" bracket
  -- col_start points to after "[", so we subtract 1 to align with the bracket
  local dropdown_row = parent_row + dropdown.line
  local dropdown_col = parent_col + dropdown.col_start - 1

  -- Dropdown dimensions - match the dropdown field width (including brackets)
  -- text_width is the content width, add 2 for brackets
  local width = (dropdown.text_width or dropdown.width) + 2
  local height = math.min(#dropdown.options, dropdown.max_height or 6)

  -- Build initial content using ContentBuilder
  local cb = self:_build_dropdown_content()
  local lines = cb:build_lines()

  -- Get UiFloat for creating the dropdown
  local UiFloat = require('ssns.ui.core.float')

  -- Create dropdown using UiFloat for proper theming and scrollbar
  self._dropdown_float = UiFloat.create(lines, {
    -- Explicit positioning (no centering)
    centered = false,
    relative = "editor",
    row = dropdown_row,
    col = dropdown_col,
    width = width,
    height = height,
    -- Styling
    border = "rounded",
    zindex = UiFloat.ZINDEX.DROPDOWN,
    -- Window options
    cursorline = true,
    focusable = true,
    enter = true,
    wrap = false,  -- Allow horizontal scrolling for long labels
    -- Disable default keymaps (we set our own)
    default_keymaps = false,
    -- Scrollbar for long lists
    scrollbar = true,
  })

  if not self._dropdown_float or not self._dropdown_float:is_valid() then
    self._dropdown_open = false
    self._dropdown_key = nil
    return
  end

  -- Apply highlights from ContentBuilder
  self._dropdown_ns = vim.api.nvim_create_namespace("ssns_dropdown_content")
  cb:apply_to_buffer(self._dropdown_float.bufnr, self._dropdown_ns)

  -- Position cursor on selected item
  if self._dropdown_selected_idx <= height then
    self._dropdown_float:set_cursor(self._dropdown_selected_idx, 0)
  end

  -- Setup dropdown keymaps
  self:_setup_dropdown_keymaps()

  -- Setup autocmds for focus-lost detection
  self:_setup_dropdown_autocmds()
end

---Build dropdown content using ContentBuilder
---@return ContentBuilder cb
function InputManager:_build_dropdown_content()
  local ContentBuilder = require('ssns.ui.core.content_builder')
  local cb = ContentBuilder.new()

  local key = self._dropdown_key
  local dropdown = self.dropdowns[key]
  if not dropdown then return cb end

  local filtered = self._dropdown_filtered_options or dropdown.options

  -- Calculate max label width for proper padding
  local max_label_len = 0
  for _, opt in ipairs(filtered) do
    max_label_len = math.max(max_label_len, #opt.label)
  end

  for _, opt in ipairs(filtered) do
    local is_original = (opt.value == self._dropdown_original_value)
    -- Pad label for alignment
    local padded_label = opt.label .. string.rep(" ", max_label_len - #opt.label)

    if is_original then
      -- Original value gets special styling with indicator
      cb:spans({
        { text = " ", style = "normal" },
        { text = padded_label, style = "emphasis" },
        { text = " *", style = "success" },
      })
    else
      -- Regular option
      cb:spans({
        { text = " ", style = "normal" },
        { text = padded_label, style = "value" },
      })
    end
  end

  if #filtered == 0 then
    cb:styled(" (no matches)", "muted")
  end

  return cb
end

---Close dropdown window
---@param cancel boolean Whether to cancel (restore original value)
function InputManager:_close_dropdown(cancel)
  if not self._dropdown_open then return end

  local key = self._dropdown_key

  -- Cancel = restore original value
  if cancel and key and self._dropdown_original_value ~= nil then
    self.dropdown_values[key] = self._dropdown_original_value
    self:_update_dropdown_display(key)
  end

  -- Clean up autocmds
  if self._dropdown_autocmd_group then
    pcall(vim.api.nvim_del_augroup_by_id, self._dropdown_autocmd_group)
    self._dropdown_autocmd_group = nil
  end

  -- Close dropdown FloatWindow (handles window and buffer cleanup)
  if self._dropdown_float then
    pcall(function() self._dropdown_float:close() end)
  end

  -- Reset state
  self._dropdown_open = false
  self._dropdown_key = nil
  self._dropdown_float = nil
  self._dropdown_ns = nil
  self._dropdown_selected_idx = 1
  self._dropdown_original_value = nil
  self._dropdown_filtered_options = nil
  self._dropdown_filter_text = ""

  -- Return focus to parent window
  if vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_set_current_win(self.winid)
  end

  -- Re-highlight current field
  if key then
    self:_highlight_current_field(key)
  end
end

---Select current dropdown option
function InputManager:_select_dropdown()
  if not self._dropdown_open or not self._dropdown_key then return end

  local key = self._dropdown_key
  local dropdown = self.dropdowns[key]
  if not dropdown then return end

  -- Get selected option
  local filtered = self._dropdown_filtered_options or dropdown.options
  local selected_opt = filtered[self._dropdown_selected_idx]

  if selected_opt then
    local old_value = self.dropdown_values[key]
    self.dropdown_values[key] = selected_opt.value

    -- Callback if value changed
    if self.on_dropdown_change and selected_opt.value ~= old_value then
      self.on_dropdown_change(key, selected_opt.value)
    end
  end

  self:_close_dropdown(false)
end

---Render dropdown options
function InputManager:_render_dropdown()
  if not self._dropdown_float or not self._dropdown_float:is_valid() then return end

  -- Build content with ContentBuilder
  local cb = self:_build_dropdown_content()
  local lines = cb:build_lines()

  -- Update lines
  self._dropdown_float:update_lines(lines)

  -- Reapply highlights
  if self._dropdown_ns then
    cb:apply_to_buffer(self._dropdown_float.bufnr, self._dropdown_ns)
  end
end

---Navigate dropdown selection
---@param direction number 1 for down, -1 for up
function InputManager:_navigate_dropdown(direction)
  if not self._dropdown_open then return end

  local filtered = self._dropdown_filtered_options or {}
  if #filtered == 0 then return end

  -- Update selection index
  self._dropdown_selected_idx = self._dropdown_selected_idx + direction

  -- Wrap around
  if self._dropdown_selected_idx < 1 then
    self._dropdown_selected_idx = #filtered
  elseif self._dropdown_selected_idx > #filtered then
    self._dropdown_selected_idx = 1
  end

  -- Move cursor in dropdown window
  if self._dropdown_float and self._dropdown_float:is_valid() then
    self._dropdown_float:set_cursor(self._dropdown_selected_idx, 0)
  end

  -- Live preview: update parent display
  local selected_opt = filtered[self._dropdown_selected_idx]
  if selected_opt and self._dropdown_key then
    self.dropdown_values[self._dropdown_key] = selected_opt.value
    self:_update_dropdown_display(self._dropdown_key)
  end
end

---Filter dropdown options based on typed text
---@param char string Character to add to filter
function InputManager:_filter_dropdown(char)
  if not self._dropdown_open or not self._dropdown_key then return end

  local dropdown = self.dropdowns[self._dropdown_key]
  if not dropdown then return end

  -- Add character to filter
  self._dropdown_filter_text = self._dropdown_filter_text .. char
  local filter_lower = self._dropdown_filter_text:lower()

  -- Filter options
  self._dropdown_filtered_options = {}
  for _, opt in ipairs(dropdown.options) do
    if opt.label:lower():find(filter_lower, 1, true) then
      table.insert(self._dropdown_filtered_options, opt)
    end
  end

  -- Reset selection to first match
  self._dropdown_selected_idx = 1

  -- Re-render
  self:_render_dropdown()

  -- Update window height
  local height = math.min(#self._dropdown_filtered_options, dropdown.max_height or 6)
  height = math.max(height, 1)  -- At least 1 line

  if self._dropdown_float and self._dropdown_float:is_valid() then
    vim.api.nvim_win_set_config(self._dropdown_float.winid, {
      height = height,
    })

    -- Position cursor
    if #self._dropdown_filtered_options > 0 then
      self._dropdown_float:set_cursor(1, 0)

      -- Live preview first match
      local first_opt = self._dropdown_filtered_options[1]
      if first_opt then
        self.dropdown_values[self._dropdown_key] = first_opt.value
        self:_update_dropdown_display(self._dropdown_key)
      end
    end
  end
end

---Clear dropdown filter
function InputManager:_clear_dropdown_filter()
  if not self._dropdown_open or not self._dropdown_key then return end

  local dropdown = self.dropdowns[self._dropdown_key]
  if not dropdown then return end

  self._dropdown_filter_text = ""
  self._dropdown_filtered_options = vim.deepcopy(dropdown.options)
  self._dropdown_selected_idx = 1

  -- Re-render
  self:_render_dropdown()

  -- Update window height
  local height = math.min(#dropdown.options, dropdown.max_height or 6)
  if self._dropdown_float and self._dropdown_float:is_valid() then
    vim.api.nvim_win_set_config(self._dropdown_float.winid, {
      height = height,
    })
    self._dropdown_float:set_cursor(1, 0)
  end
end

---Update dropdown display in parent buffer
---@param key string Dropdown key
function InputManager:_update_dropdown_display(key)
  local dropdown = self.dropdowns[key]
  if not dropdown then return end

  local value = self.dropdown_values[key]

  -- Find label for value
  local display_text = dropdown.placeholder or "(select)"
  local is_placeholder = true
  for _, opt in ipairs(dropdown.options) do
    if opt.value == value then
      display_text = opt.label
      is_placeholder = false
      break
    end
  end

  -- Calculate dimensions (text_width is in display columns)
  local arrow = " ▼"
  local text_width = dropdown.text_width or 18

  -- Pad or truncate using display width
  local display_len = vim.fn.strdisplaywidth(display_text)
  if display_len < text_width then
    display_text = display_text .. string.rep(" ", text_width - display_len)
  elseif display_len > text_width then
    -- Truncate with ellipsis - use vim.fn.strcharpart for proper UTF-8 handling
    local truncated = ""
    local current_width = 0
    local char_idx = 0
    while current_width < text_width - 1 do
      local char = vim.fn.strcharpart(display_text, char_idx, 1)
      if char == "" then break end
      local char_width = vim.fn.strdisplaywidth(char)
      if current_width + char_width > text_width - 1 then
        break
      end
      truncated = truncated .. char
      current_width = current_width + char_width
      char_idx = char_idx + 1
    end
    -- Pad to exact width and add ellipsis
    local pad_needed = text_width - 1 - vim.fn.strdisplaywidth(truncated)
    if pad_needed > 0 then
      truncated = truncated .. string.rep(" ", pad_needed)
    end
    display_text = truncated .. "…"
  end

  -- Get current line
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, dropdown.line - 1, dropdown.line, false)
  if #lines == 0 then return end

  local line = lines[1]

  -- Find brackets
  local bracket_pos = line:find("%]", dropdown.col_start + 1)
  if not bracket_pos then return end

  -- Reconstruct line
  local before = line:sub(1, dropdown.col_start)
  local after = line:sub(bracket_pos + 1)
  local new_line = before .. display_text .. arrow .. "]" .. after

  -- Update buffer
  local was_modifiable = vim.api.nvim_buf_get_option(self.bufnr, 'modifiable')
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(self.bufnr, dropdown.line - 1, dropdown.line, false, {new_line})
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', was_modifiable)

  -- Update placeholder state
  dropdown.is_placeholder = is_placeholder
end

---Setup keymaps for dropdown window
function InputManager:_setup_dropdown_keymaps()
  if not self._dropdown_float or not self._dropdown_float:is_valid() then return end

  local bufnr = self._dropdown_float.bufnr
  local opts = { buffer = bufnr, noremap = true, silent = true, nowait = true }

  -- Navigation
  vim.keymap.set('n', 'j', function() self:_navigate_dropdown(1) end, opts)
  vim.keymap.set('n', 'k', function() self:_navigate_dropdown(-1) end, opts)
  vim.keymap.set('n', '<Down>', function() self:_navigate_dropdown(1) end, opts)
  vim.keymap.set('n', '<Up>', function() self:_navigate_dropdown(-1) end, opts)

  -- Select
  vim.keymap.set('n', '<CR>', function() self:_select_dropdown() end, opts)

  -- Cancel
  vim.keymap.set('n', '<Esc>', function() self:_close_dropdown(true) end, opts)
  vim.keymap.set('n', 'q', function() self:_close_dropdown(true) end, opts)

  -- Note: h/l/w/b etc are NOT mapped so users can scroll horizontally to see long labels

  -- Clear filter
  vim.keymap.set('n', '<BS>', function() self:_clear_dropdown_filter() end, opts)

  -- Type-to-filter: handle printable characters
  -- Skip navigation keys so they work normally for horizontal scrolling
  local skip_chars = {
    j = true, k = true,           -- Vertical navigation
    h = true, l = true,           -- Horizontal navigation
    w = true, b = true, e = true, -- Word navigation
    ['0'] = true, ['$'] = true, ['^'] = true, -- Line navigation
    q = true,                     -- Cancel
  }
  for char_code = 32, 126 do  -- Printable ASCII
    local char = string.char(char_code)
    if not skip_chars[char] then
      vim.keymap.set('n', char, function()
        self:_filter_dropdown(char)
      end, opts)
    end
  end
end

---Setup autocmds for dropdown focus-lost detection
function InputManager:_setup_dropdown_autocmds()
  if not self._dropdown_float or not self._dropdown_float:is_valid() then return end

  local bufnr = self._dropdown_float.bufnr
  self._dropdown_autocmd_group = vim.api.nvim_create_augroup(
    "SSNSDropdown_" .. bufnr,
    { clear = true }
  )

  -- Close on WinLeave (focus lost)
  vim.api.nvim_create_autocmd("WinLeave", {
    group = self._dropdown_autocmd_group,
    buffer = bufnr,
    callback = function()
      -- Schedule to allow checking if we're going to parent window
      vim.schedule(function()
        local current_win = vim.api.nvim_get_current_win()
        -- If leaving to a window that's not the parent, cancel
        if current_win ~= self.winid then
          self:_close_dropdown(true)
        end
      end)
    end,
  })

  -- Close on BufLeave
  vim.api.nvim_create_autocmd("BufLeave", {
    group = self._dropdown_autocmd_group,
    buffer = bufnr,
    callback = function()
      vim.schedule(function()
        self:_close_dropdown(true)
      end)
    end,
  })
end

---Get dropdown value
---@param key string Dropdown key
---@return string? value
function InputManager:get_dropdown_value(key)
  return self.dropdown_values[key]
end

---Set dropdown value
---@param key string Dropdown key
---@param value string New value
function InputManager:set_dropdown_value(key, value)
  local dropdown = self.dropdowns[key]
  if not dropdown then return end

  self.dropdown_values[key] = value
  self:_update_dropdown_display(key)
end

---Cleanup the input manager
function InputManager:destroy()
  -- Close any open dropdown first
  if self._dropdown_open then
    self:_close_dropdown(true)
  end

  if self._autocmd_group then
    pcall(vim.api.nvim_del_augroup_by_id, self._autocmd_group)
  end

  if vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_clear_namespace(self.bufnr, self._namespace, 0, -1)
  end
end

return InputManager
