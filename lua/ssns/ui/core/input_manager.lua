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
---@field on_value_change fun(key: string, value: string)? Called when input value changes
---@field on_input_enter fun(key: string)? Called when entering input mode
---@field on_input_exit fun(key: string)? Called when exiting input mode

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
  self.on_value_change = config.on_value_change
  self.on_input_enter = config.on_input_enter
  self.on_input_exit = config.on_input_exit
  
  -- State
  self.in_input_mode = false
  self.active_input = nil
  self.current_input_idx = 1  -- Track current input index for Tab navigation
  self.values = {}
  self._namespace = vim.api.nvim_create_namespace("ssns_input_manager")
  self._autocmd_group = nil
  
  -- Initialize values from input definitions and track placeholder state
  for key, input in pairs(self.inputs) do
    self.values[key] = input.value or ""
    -- Track if this input is showing placeholder
    input.is_showing_placeholder = (self.values[key] == "" and (input.placeholder or "") ~= "")
  end
  
  return self
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

---Navigate to next input field
function InputManager:next_input()
  if #self.input_order == 0 then return end
  
  -- Find next input index
  local next_idx = (self.current_input_idx % #self.input_order) + 1
  local next_key = self.input_order[next_idx]
  
  -- Update tracked index
  self.current_input_idx = next_idx
  
  -- Exit current input mode if active
  if self.in_input_mode then
    -- Stop insert mode, then enter next
    vim.cmd("stopinsert")
    vim.schedule(function()
      self:enter_input_mode(next_key)
    end)
  else
    -- Move cursor and highlight
    local input = self.inputs[next_key]
    if input then
      vim.api.nvim_win_set_cursor(self.winid, {input.line, input.col_start})
      self:_highlight_current_input(next_key)
    end
  end
end

---Navigate to previous input field
function InputManager:prev_input()
  if #self.input_order == 0 then return end
  
  -- Find previous input index
  local prev_idx = ((self.current_input_idx - 2) % #self.input_order) + 1
  local prev_key = self.input_order[prev_idx]
  
  -- Update tracked index
  self.current_input_idx = prev_idx
  
  -- Exit current input mode if active
  if self.in_input_mode then
    vim.cmd("stopinsert")
    vim.schedule(function()
      self:enter_input_mode(prev_key)
    end)
  else
    -- Move cursor and highlight
    local input = self.inputs[prev_key]
    if input then
      vim.api.nvim_win_set_cursor(self.winid, {input.line, input.col_start})
      self:_highlight_current_input(prev_key)
    end
  end
end

---Setup keymaps for input navigation
function InputManager:_setup_input_keymaps()
  local opts = { buffer = self.bufnr, noremap = true, silent = true }
  
  -- Normal mode: Enter activates input under cursor (or at current index)
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
    
    -- Otherwise, activate the current tracked input
    if #self.input_order > 0 then
      local current_key = self.input_order[self.current_input_idx]
      if current_key then
        self:enter_input_mode(current_key)
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

---Initialize highlights for all inputs (call after setup)
function InputManager:init_highlights()
  -- Highlight first input as current, others as inactive
  if #self.input_order > 0 then
    local first_key = self.input_order[1]
    self:_highlight_current_input(first_key)
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
function InputManager:update_inputs(inputs, input_order)
  self.inputs = inputs or {}
  self.input_order = input_order or {}
  
  -- Preserve existing values, add new ones, and track placeholder state
  for key, input in pairs(self.inputs) do
    if not self.values[key] then
      self.values[key] = input.value or ""
    end
    -- Update placeholder state based on current value
    local value = self.values[key] or ""
    input.is_showing_placeholder = (value == "" and (input.placeholder or "") ~= "")
  end
end

---Cleanup the input manager
function InputManager:destroy()
  if self._autocmd_group then
    pcall(vim.api.nvim_del_augroup_by_id, self._autocmd_group)
  end
  
  if vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_clear_namespace(self.bufnr, self._namespace, 0, -1)
  end
end

return InputManager
