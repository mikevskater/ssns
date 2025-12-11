---@class FloatConfig
---Configuration for floating window creation
---@field title string? Window title text
---@field title_pos "left"|"center"|"right"? Title alignment (default: "center")
---@field footer string? Footer text
---@field footer_pos "left"|"center"|"right"? Footer alignment (default: "center")
---@field border "none"|"single"|"double"|"rounded"|"solid"|"shadow"|table? Border style (default: "rounded")
---@field width number? Fixed width in columns
---@field min_width number? Minimum width
---@field max_width number? Maximum width (default: vim.o.columns - 4)
---@field height number? Fixed height in rows
---@field min_height number? Minimum height
---@field max_height number? Maximum height (default: vim.o.lines - 6)
---@field relative "editor"|"cursor"|"win"? Position relative to (default: "editor")
---@field row number? Y position (for non-centered)
---@field col number? X position (for non-centered)
---@field centered boolean? Center window on screen (default: true)
---@field enter boolean? Enter window after creation (default: true)
---@field focusable boolean? Window can receive focus (default: true)
---@field keymaps table<string, function|string>? Key -> function/command mappings
---@field default_keymaps boolean? Include default close keys (q, <Esc>) (default: true)
---@field filetype string? Buffer filetype for syntax highlighting
---@field buftype string? Buffer type (default: "nofile")
---@field readonly boolean? Make buffer read-only (default: true)
---@field modifiable boolean? Allow buffer modifications (default: false)
---@field winhighlight string? Custom window highlight groups
---@field winblend number? Window transparency 0-100 (default: 0)
---@field cursorline boolean? Highlight cursor line (default: true)
---@field wrap boolean? Enable line wrapping (default: false)
---@field zindex number? Window layer ordering (default: 50)
---@field on_close function? Callback when window closes
---@field style "minimal"|nil? Window style (default: "minimal")

---@class FloatWindow
---A floating window instance
---@field bufnr number Buffer handle
---@field winid number Window handle
---@field config FloatConfig Configuration used
---@field lines string[] Current content lines
local FloatWindow = {}
FloatWindow.__index = FloatWindow

---@class UiFloat
---Floating window utility module
local UiFloat = {}

---Create a new floating window
---@param lines string[]? Initial content lines (optional)
---@param config FloatConfig? Configuration options
---@return FloatWindow instance
function UiFloat.create(lines, config)
  lines = lines or {}
  config = config or {}

  local instance = setmetatable({
    bufnr = nil,
    winid = nil,
    config = config,
    lines = lines,
  }, FloatWindow)

  -- Apply defaults
  instance:_apply_defaults()

  -- Create buffer
  instance:_create_buffer()

  -- Calculate dimensions
  local width, height = instance:_calculate_dimensions()

  -- Calculate position
  local row, col = instance:_calculate_position(width, height)

  -- Open window
  instance:_open_window(width, height, row, col)

  -- Setup buffer and window options
  instance:_setup_options()

  -- Setup keymaps
  instance:_setup_keymaps()

  -- Setup autocmds
  instance:_setup_autocmds()

  return instance
end

---Apply default configuration values
function FloatWindow:_apply_defaults()
  local c = self.config

  c.title_pos = c.title_pos or "center"
  c.footer_pos = c.footer_pos or "center"
  c.border = c.border or "rounded"
  c.max_width = c.max_width or (vim.o.columns - 4)
  c.max_height = c.max_height or (vim.o.lines - 6)
  c.relative = c.relative or "editor"
  c.centered = c.centered ~= false  -- Default true
  c.enter = c.enter ~= false  -- Default true
  c.focusable = c.focusable ~= false  -- Default true
  c.default_keymaps = c.default_keymaps ~= false  -- Default true
  c.buftype = c.buftype or "nofile"
  c.readonly = c.readonly ~= false  -- Default true
  c.modifiable = c.modifiable or false
  c.winblend = c.winblend or 0
  c.cursorline = c.cursorline ~= false  -- Default true
  c.wrap = c.wrap or false
  c.zindex = c.zindex or 50
  c.style = c.style or "minimal"
end

---Create the buffer
function FloatWindow:_create_buffer()
  self.bufnr = vim.api.nvim_create_buf(false, true)  -- unlisted, scratch

  -- Set buffer options
  vim.api.nvim_buf_set_option(self.bufnr, 'buftype', self.config.buftype)
  vim.api.nvim_buf_set_option(self.bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(self.bufnr, 'swapfile', false)

  if self.config.filetype then
    vim.api.nvim_buf_set_option(self.bufnr, 'filetype', self.config.filetype)
  end

  -- Set initial content
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, self.lines)

  -- Set modifiable
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', self.config.modifiable)
end

---Calculate window dimensions
---@return number width, number height
function FloatWindow:_calculate_dimensions()
  local width = self.config.width
  local height = self.config.height

  -- Auto-calculate width if not specified
  if not width then
    width = self.config.min_width or 60

    -- Calculate content width
    local max_line_width = 0
    for _, line in ipairs(self.lines) do
      local line_width = vim.fn.strdisplaywidth(line)
      if line_width > max_line_width then
        max_line_width = line_width
      end
    end

    -- Use content width if larger than min
    if max_line_width > width then
      width = max_line_width
    end
  end

  -- Auto-calculate height if not specified
  if not height then
    height = #self.lines  -- Use content height, constraints applied below
  end

  -- Apply constraints
  if self.config.min_width then
    width = math.max(width, self.config.min_width)
  end
  if self.config.max_width then
    width = math.min(width, self.config.max_width)
  end
  if self.config.min_height then
    height = math.max(height, self.config.min_height)
  end
  if self.config.max_height then
    -- Ensure max_height doesn't exceed available screen space (account for borders + cmdline)
    local screen_max = vim.o.lines - 6
    local effective_max = math.min(self.config.max_height, screen_max)
    height = math.min(height, effective_max)
  end

  -- Account for title/footer if present
  if self.config.title then
    local title_width = vim.fn.strdisplaywidth(self.config.title) + 2  -- Add padding
    width = math.max(width, title_width)
  end
  if self.config.footer then
    local footer_width = vim.fn.strdisplaywidth(self.config.footer) + 2
    width = math.max(width, footer_width)
  end

  return width, height
end

---Calculate window position
---@param width number Window width
---@param height number Window height
---@return number row, number col
function FloatWindow:_calculate_position(width, height)
  local row, col

  if self.config.centered then
    -- Center on screen
    row = math.floor((vim.o.lines - height) / 2)
    col = math.floor((vim.o.columns - width) / 2)
  elseif self.config.relative == "cursor" then
    -- Position relative to cursor
    row = self.config.row or 1
    col = self.config.col or 0
  else
    -- Use specified position
    row = self.config.row or 0
    col = self.config.col or 0
  end

  -- Ensure window stays on screen (account for borders: 2 lines, cmdline: 2 lines)
  row = math.max(0, math.min(row, vim.o.lines - height - 4))
  col = math.max(0, math.min(col, vim.o.columns - width - 2))

  return row, col
end

---Open the floating window
---@param width number Window width
---@param height number Window height
---@param row number Y position
---@param col number X position
function FloatWindow:_open_window(width, height, row, col)
  local win_config = {
    relative = self.config.relative,
    width = width,
    height = height,
    row = row,
    col = col,
    style = self.config.style,
    border = self.config.border,
    focusable = self.config.focusable,
    zindex = self.config.zindex,
  }

  -- Add title if specified
  if self.config.title then
    win_config.title = string.format(" %s ", self.config.title)
    win_config.title_pos = self.config.title_pos
  end

  -- Add footer if specified
  if self.config.footer then
    win_config.footer = string.format(" %s ", self.config.footer)
    win_config.footer_pos = self.config.footer_pos
  end

  self.winid = vim.api.nvim_open_win(self.bufnr, self.config.enter, win_config)
end

---Setup window and buffer options
function FloatWindow:_setup_options()
  local winid = self.winid

  -- Window options
  vim.api.nvim_set_option_value('wrap', self.config.wrap, { win = winid })
  vim.api.nvim_set_option_value('foldenable', false, { win = winid })
  vim.api.nvim_set_option_value('cursorline', self.config.cursorline, { win = winid })
  vim.api.nvim_set_option_value('number', false, { win = winid })
  vim.api.nvim_set_option_value('relativenumber', false, { win = winid })
  vim.api.nvim_set_option_value('signcolumn', 'no', { win = winid })
  vim.api.nvim_set_option_value('winblend', self.config.winblend, { win = winid })
  vim.api.nvim_set_option_value('scrolloff', 0, { win = winid })

  -- Apply themed highlight groups (allow override via winhighlight config)
  local default_winhighlight = 'Normal:Normal,FloatBorder:SsnsFloatBorder,FloatTitle:SsnsFloatTitle,CursorLine:SsnsFloatSelected'
  local winhighlight = self.config.winhighlight or default_winhighlight
  vim.api.nvim_set_option_value('winhighlight', winhighlight, { win = winid })
end

---Setup keymaps
function FloatWindow:_setup_keymaps()
  local bufnr = self.bufnr
  local winid = self.winid

  -- Default close keymaps
  if self.config.default_keymaps then
    vim.keymap.set('n', 'q', function()
      self:close()
    end, { buffer = bufnr, noremap = true, silent = true, desc = "Close window" })

    vim.keymap.set('n', '<Esc>', function()
      self:close()
    end, { buffer = bufnr, noremap = true, silent = true, desc = "Close window" })
  end

  -- Custom keymaps
  if self.config.keymaps then
    for key, handler in pairs(self.config.keymaps) do
      if type(handler) == "function" then
        vim.keymap.set('n', key, handler, { buffer = bufnr, noremap = true, silent = true })
      elseif type(handler) == "string" then
        vim.keymap.set('n', key, handler, { buffer = bufnr, noremap = true, silent = true })
      end
    end
  end
end

---Setup autocmds for cleanup
function FloatWindow:_setup_autocmds()
  if self.config.on_close then
    vim.api.nvim_create_autocmd("BufWipeout", {
      buffer = self.bufnr,
      once = true,
      callback = function()
        if self.config.on_close then
          self.config.on_close()
        end
      end,
    })
  end
end

---Update window content
---@param lines string[] New content lines
function FloatWindow:update_lines(lines)
  if not self:is_valid() then
    return
  end

  self.lines = lines

  -- Make buffer modifiable temporarily
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', self.config.modifiable)
end

---Close the floating window
function FloatWindow:close()
  if self:is_valid() then
    if vim.api.nvim_buf_is_valid(self.bufnr) then
      vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end
    self.winid = nil
    self.bufnr = nil
  end
end

---Check if window is still valid
---@return boolean
function FloatWindow:is_valid()
  return self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr)
    and self.winid and vim.api.nvim_win_is_valid(self.winid)
end

---Focus the window
function FloatWindow:focus()
  if self:is_valid() then
    vim.api.nvim_set_current_win(self.winid)
  end
end

---Get current cursor position in window
---@return number row, number col (1-indexed)
function FloatWindow:get_cursor()
  if self:is_valid() then
    return unpack(vim.api.nvim_win_get_cursor(self.winid))
  end
  return 1, 0
end

---Set cursor position
---@param row number Row (1-indexed)
---@param col number Column (0-indexed)
function FloatWindow:set_cursor(row, col)
  if self:is_valid() then
    vim.api.nvim_win_set_cursor(self.winid, { row, col })
  end
end

---Create a simple confirmation dialog
---@param message string|string[] Message to display
---@param on_confirm function Callback on confirmation
---@param on_cancel function? Callback on cancel (optional)
---@return FloatWindow
function UiFloat.confirm(message, on_confirm, on_cancel)
  local lines = type(message) == "table" and message or { message }
  table.insert(lines, "")
  table.insert(lines, "Press 'y' to confirm, 'n' to cancel")

  return UiFloat.create(lines, {
    title = "Confirm",
    border = "rounded",
    width = 50,
    keymaps = {
      y = function()
        if on_confirm then on_confirm() end
        vim.cmd('close')
      end,
      n = function()
        if on_cancel then on_cancel() end
        vim.cmd('close')
      end,
    }
  })
end

---Create a simple info dialog
---@param message string|string[] Message to display
---@param title string? Optional title
---@return FloatWindow
function UiFloat.info(message, title)
  local lines = type(message) == "table" and message or { message }

  return UiFloat.create(lines, {
    title = title or "Info",
    border = "rounded",
    width = 50,
  })
end

---Create a selection menu
---@param items string[] List of items
---@param on_select function Callback with selected index
---@param title string? Optional title
---@return FloatWindow
function UiFloat.select(items, on_select, title)
  local lines = {}
  for i, item in ipairs(items) do
    table.insert(lines, string.format("[%d] %s", i, item))
  end

  return UiFloat.create(lines, {
    title = title or "Select",
    border = "rounded",
    max_height = 20,
    cursorline = true,
    keymaps = {
      ['<CR>'] = function()
        local win = vim.api.nvim_get_current_win()
        local row = vim.api.nvim_win_get_cursor(win)[1]
        if row > 0 and row <= #items then
          vim.cmd('close')
          if on_select then
            on_select(row, items[row])
          end
        end
      end,
    }
  })
end

---Create a styled floating window using ContentBuilder
---@param content_builder ContentBuilder ContentBuilder instance with styled content
---@param config FloatConfig? Configuration options
---@return FloatWindow instance
function UiFloat.create_styled(content_builder, config)
  config = config or {}
  
  -- Get plain lines for initial content
  local lines = content_builder:build_lines()
  
  -- Create the float window
  local instance = UiFloat.create(lines, config)
  
  -- Apply highlights from ContentBuilder
  if instance:is_valid() then
    local ns_id = vim.api.nvim_create_namespace("ssns_float_content")
    content_builder:apply_to_buffer(instance.bufnr, ns_id)
    instance._content_ns = ns_id
    instance._content_builder = content_builder
  end
  
  return instance
end

---Update a styled window with new ContentBuilder content
---@param content_builder ContentBuilder New styled content
function FloatWindow:update_styled(content_builder)
  if not self:is_valid() then
    return
  end
  
  -- Update lines
  local lines = content_builder:build_lines()
  self:update_lines(lines)
  
  -- Reapply highlights
  local ns_id = self._content_ns or vim.api.nvim_create_namespace("ssns_float_content")
  content_builder:apply_to_buffer(self.bufnr, ns_id)
  self._content_ns = ns_id
  self._content_builder = content_builder
end

---Get the ContentBuilder module for convenience
---@return ContentBuilder
function UiFloat.ContentBuilder()
  return require('ssns.ui.core.content_builder')
end

return UiFloat
