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
---@field col_end number 0-indexed end column of input value area
---@field width number Total width of input field
---@field value string Current value
---@field default string Default/initial value
---@field placeholder string Placeholder text when empty

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
  self.values = {}
  self._namespace = vim.api.nvim_create_namespace("ssns_input_manager")
  self._autocmd_group = nil
  
  -- Initialize values from input definitions
  for key, input in pairs(self.inputs) do
    self.values[key] = input.value or ""
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
  
  -- Handle text changes in insert mode
  vim.api.nvim_create_autocmd("TextChangedI", {
    group = self._autocmd_group,
    buffer = self.bufnr,
    callback = function()
      if self.in_input_mode and self.active_input then
        self:_sync_input_value()
      end
    end,
  })
  
  -- Setup Tab/Shift-Tab for input navigation
  self:_setup_input_keymaps()
end

---Check if cursor is on an input field and enter input mode if so
function InputManager:_check_cursor_on_input()
  local cursor = vim.api.nvim_win_get_cursor(self.winid)
  local row = cursor[1]  -- 1-indexed
  local col = cursor[2]  -- 0-indexed
  
  -- Find input at cursor position
  for key, input in pairs(self.inputs) do
    if input.line == row and col >= input.col_start and col < input.col_end then
      -- Cursor is on this input - don't auto-enter, but highlight it
      self:_highlight_input(key, true)
      return
    end
  end
  
  -- Not on any input - clear highlights
  self:_clear_input_highlights()
end

---Enter input mode for a specific input field
---@param key string Input key to activate
function InputManager:enter_input_mode(key)
  local input = self.inputs[key]
  if not input then return end
  
  self.in_input_mode = true
  self.active_input = key
  
  -- Make buffer modifiable
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', true)
  
  -- Position cursor at end of current value
  local value = self.values[key] or ""
  local cursor_col = input.col_start + #value
  cursor_col = math.min(cursor_col, input.col_end - 1)
  
  vim.api.nvim_win_set_cursor(self.winid, {input.line, cursor_col})
  
  -- Highlight active input
  self:_highlight_input(key, true)
  
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
  
  -- Make buffer non-modifiable again
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', false)
  
  -- Clear highlights
  self:_clear_input_highlights()
  
  -- Callback
  if self.on_input_exit and exited_key then
    self.on_input_exit(exited_key)
  end
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
  
  -- Extract value from input area (between col_start and col_end)
  local raw_value = line_text:sub(input.col_start + 1, input.col_end)
  
  -- Trim trailing spaces (but preserve leading spaces if user wants them)
  local value = raw_value:gsub("%s+$", "")
  
  -- Update stored value
  local old_value = self.values[self.active_input]
  self.values[self.active_input] = value
  
  -- Callback if changed
  if self.on_value_change and value ~= old_value then
    self.on_value_change(self.active_input, value)
  end
end

---Navigate to next input field
function InputManager:next_input()
  if #self.input_order == 0 then return end
  
  local current_idx = 1
  if self.active_input then
    for i, key in ipairs(self.input_order) do
      if key == self.active_input then
        current_idx = i
        break
      end
    end
  end
  
  -- Find next input
  local next_idx = (current_idx % #self.input_order) + 1
  local next_key = self.input_order[next_idx]
  
  -- Exit current input mode if active
  if self.in_input_mode then
    -- Stop insert mode, then enter next
    vim.cmd("stopinsert")
    vim.schedule(function()
      self:enter_input_mode(next_key)
    end)
  else
    -- Just move to next input
    local input = self.inputs[next_key]
    if input then
      vim.api.nvim_win_set_cursor(self.winid, {input.line, input.col_start})
    end
  end
end

---Navigate to previous input field
function InputManager:prev_input()
  if #self.input_order == 0 then return end
  
  local current_idx = 1
  if self.active_input then
    for i, key in ipairs(self.input_order) do
      if key == self.active_input then
        current_idx = i
        break
      end
    end
  end
  
  -- Find previous input
  local prev_idx = ((current_idx - 2) % #self.input_order) + 1
  local prev_key = self.input_order[prev_idx]
  
  -- Exit current input mode if active
  if self.in_input_mode then
    vim.cmd("stopinsert")
    vim.schedule(function()
      self:enter_input_mode(prev_key)
    end)
  else
    local input = self.inputs[prev_key]
    if input then
      vim.api.nvim_win_set_cursor(self.winid, {input.line, input.col_start})
    end
  end
end

---Setup keymaps for input navigation
function InputManager:_setup_input_keymaps()
  local opts = { buffer = self.bufnr, noremap = true, silent = true }
  
  -- Normal mode: Enter activates input under cursor
  vim.keymap.set('n', '<CR>', function()
    local cursor = vim.api.nvim_win_get_cursor(self.winid)
    local row = cursor[1]
    local col = cursor[2]
    
    -- Find input at cursor
    for key, input in pairs(self.inputs) do
      if input.line == row and col >= input.col_start and col < input.col_end then
        self:enter_input_mode(key)
        return
      end
    end
  end, opts)
  
  -- Normal mode Tab/Shift-Tab: move between inputs
  vim.keymap.set('n', '<Tab>', function()
    self:next_input()
  end, opts)
  
  vim.keymap.set('n', '<S-Tab>', function()
    self:prev_input()
  end, opts)
  
  -- Insert mode Tab/Shift-Tab: move between inputs
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
      if cursor[2] < max_col and cursor[2] < input.col_end - 1 then
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
---@param active boolean Whether input is active
function InputManager:_highlight_input(key, active)
  local input = self.inputs[key]
  if not input then return end
  
  -- Clear existing highlights first
  vim.api.nvim_buf_clear_namespace(self.bufnr, self._namespace, input.line - 1, input.line)
  
  -- Apply active/inactive highlight
  local hl_group = active and "SsnsFloatInputActive" or "SsnsFloatInput"
  vim.api.nvim_buf_add_highlight(
    self.bufnr, self._namespace, hl_group,
    input.line - 1, input.col_start, input.col_end
  )
end

---Clear all input highlights
function InputManager:_clear_input_highlights()
  vim.api.nvim_buf_clear_namespace(self.bufnr, self._namespace, 0, -1)
  
  -- Reapply inactive highlights to all inputs
  for key, _ in pairs(self.inputs) do
    self:_highlight_input(key, false)
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

---Render an input field's value to the buffer
---@param key string Input key
function InputManager:_render_input(key)
  local input = self.inputs[key]
  if not input then return end
  
  local value = self.values[key] or ""
  local placeholder = input.placeholder or ""
  local width = input.width
  
  -- Determine display text
  local display_text = value
  if value == "" and placeholder ~= "" then
    display_text = placeholder
  end
  
  -- Pad to width
  if #display_text < width then
    display_text = display_text .. string.rep(" ", width - #display_text)
  elseif #display_text > width then
    display_text = display_text:sub(1, width)
  end
  
  -- Get current line
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, input.line - 1, input.line, false)
  if #lines == 0 then return end
  
  local line = lines[1]
  
  -- Replace input area in line
  local before = line:sub(1, input.col_start)
  local after = line:sub(input.col_end + 1)
  local new_line = before .. display_text .. after
  
  -- Update buffer
  local was_modifiable = vim.api.nvim_buf_get_option(self.bufnr, 'modifiable')
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(self.bufnr, input.line - 1, input.line, false, {new_line})
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', was_modifiable)
end

---Update input definitions (e.g., after re-render)
---@param inputs table<string, InputField> New input definitions
---@param input_order string[] New input order
function InputManager:update_inputs(inputs, input_order)
  self.inputs = inputs or {}
  self.input_order = input_order or {}
  
  -- Preserve existing values, add new ones
  for key, input in pairs(self.inputs) do
    if not self.values[key] then
      self.values[key] = input.value or ""
    end
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
