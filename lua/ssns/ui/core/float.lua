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
---@field content_builder ContentBuilder? ContentBuilder instance for styled content with inputs
---@field enable_inputs boolean? Enable input field mode for the window
---@field scrollbar boolean? Show scrollbar when content exceeds window height (default: true)

---Scrollbar characters
local SCROLLBAR_CHARS = {
  UP_ARROW = "▲",
  DOWN_ARROW = "▼",
  THUMB = "█",
  TRACK = "░",
}

---@class FloatWindow
---A floating window instance
---@field bufnr number Buffer handle
---@field winid number Window handle
---@field config FloatConfig Configuration used
---@field lines string[] Current content lines
---@field _scrollbar_winid number? Scrollbar window handle
---@field _scrollbar_bufnr number? Scrollbar buffer handle
---@field _scrollbar_autocmd number? Autocmd ID for scroll tracking
local FloatWindow = {}
FloatWindow.__index = FloatWindow

---@class UiFloat
---Floating window utility module
local UiFloat = {}

---Create a new floating window
---@param lines string[]|FloatConfig? Initial content lines OR config (for convenience)
---@param config FloatConfig? Configuration options
---@return FloatWindow instance
function UiFloat.create(lines, config)
  -- Handle convenience call pattern: UiFloat.create({ title = "...", ... })
  -- If first arg is a table with config keys (not an array), treat it as config
  if type(lines) == "table" and not vim.islist(lines) then
    config = lines
    lines = {}
  end
  
  lines = lines or {}
  config = config or {}

  -- Handle content_builder in config
  local content_builder = config.content_builder
  local content_builder_is_new = false
  
  if content_builder == true then
    -- Create a new ContentBuilder if boolean true passed
    -- Don't build lines yet - user will populate it and call render()
    local ContentBuilder = require('ssns.ui.core.content_builder')
    content_builder = ContentBuilder.new()
    config.content_builder = content_builder
    content_builder_is_new = true
    -- Start with empty lines - will be populated on render()
    lines = {""}
  elseif content_builder and type(content_builder) == "table" and content_builder.build_lines then
    -- Pre-populated ContentBuilder was passed, use its lines
    lines = content_builder:build_lines()
  end

  local instance = setmetatable({
    bufnr = nil,
    winid = nil,
    config = config,
    lines = lines,
    _input_manager = nil,
    _content_builder = content_builder,
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

  -- Store window geometry for scrollbar
  instance._win_row = row
  instance._win_col = col
  instance._win_width = width
  instance._win_height = height

  -- Setup buffer and window options
  instance:_setup_options()

  -- Setup keymaps
  instance:_setup_keymaps()

  -- Setup autocmds
  instance:_setup_autocmds()

  -- Setup scrollbar if enabled and content exceeds window height
  if instance.config.scrollbar then
    instance:_setup_scrollbar()
  end

  -- Apply styled content if content_builder provided
  if content_builder and instance:is_valid() then
    local ns_id = vim.api.nvim_create_namespace("ssns_float_content")
    content_builder:apply_to_buffer(instance.bufnr, ns_id)
    instance._content_ns = ns_id
    
    -- Setup inputs if enabled
    if config.enable_inputs then
      instance:_setup_input_manager(content_builder)
    end
  end

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
  c.scrollbar = c.scrollbar ~= false  -- Default true
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

  -- If both width and height are explicitly set, use them directly (for raw positioning)
  if width and height then
    return width, height
  end

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

  -- If row and col are explicitly set with centered=false, use them directly (for raw positioning)
  if not self.config.centered and self.config.row and self.config.col then
    return self.config.row, self.config.col
  end

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

  -- Update scrollbar if enabled
  if self.config.scrollbar then
    self:_update_scrollbar()
  end
end

---Close the floating window
function FloatWindow:close()
  -- Clean up scrollbar first
  self:_close_scrollbar()

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

---Get the content builder associated with this window
---@return ContentBuilder?
function FloatWindow:get_content_builder()
  return self._content_builder
end

---Render/update content from content builder
---Call this after modifying the content builder to refresh the display
function FloatWindow:render()
  if not self:is_valid() then return end
  
  local cb = self._content_builder
  if not cb then return end
  
  -- Build lines from content builder
  local lines = cb:build_lines()
  
  -- Make buffer modifiable temporarily
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', true)
  
  -- Set content
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  
  -- Apply highlights
  local ns_id = self._content_ns or vim.api.nvim_create_namespace("ssns_float_content")
  self._content_ns = ns_id
  vim.api.nvim_buf_clear_namespace(self.bufnr, ns_id, 0, -1)
  cb:apply_to_buffer(self.bufnr, ns_id)
  
  -- Setup inputs if enabled
  if self.config.enable_inputs then
    self:_setup_input_manager(cb)
  end
  
  -- Restore modifiable state
  vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', self.config.modifiable or false)
  
  -- Update stored lines
  self.lines = lines

  -- Update scrollbar if enabled
  if self.config.scrollbar then
    self:_update_scrollbar()
  end
end

-- ============================================================================
-- Input Field Support for FloatWindow
-- ============================================================================

---Setup input manager from content builder
---@param content_builder ContentBuilder
function FloatWindow:_setup_input_manager(content_builder)
  local InputManager = require('ssns.ui.core.input_manager')
  
  local inputs = content_builder:get_inputs()
  local input_order = content_builder:get_input_order()
  
  -- Create input manager
  self._input_manager = InputManager.new({
    bufnr = self.bufnr,
    winid = self.winid,
    inputs = inputs,
    input_order = input_order,
  })
  
  -- Setup input mode handling
  self._input_manager:setup()
  
  -- Initialize highlights for all inputs
  self._input_manager:init_highlights()
  
  -- Position cursor on first input if available (schedule to ensure window is ready)
  if #input_order > 0 then
    local first_input = inputs[input_order[1]]
    if first_input then
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(self.winid) then
          vim.api.nvim_win_set_cursor(self.winid, {first_input.line, first_input.col_start})
        end
      end)
    end
  end
end

---Show the float (alias for focus)
function FloatWindow:show()
  self:focus()
end

---Enter input mode for a specific input or current input under cursor
---@param key string? Input key (optional - uses cursor position if not provided)
function FloatWindow:enter_input(key)
  if not self._input_manager then return end
  
  if key then
    self._input_manager:enter_input_mode(key)
  else
    -- Find input under cursor
    local cursor = vim.api.nvim_win_get_cursor(self.winid)
    local row = cursor[1]
    local col = cursor[2]
    
    for input_key, input in pairs(self._input_manager.inputs) do
      if input.line == row and col >= input.col_start and col < input.col_end then
        self._input_manager:enter_input_mode(input_key)
        return
      end
    end
  end
end

---Navigate to next input
function FloatWindow:next_input()
  if self._input_manager then
    self._input_manager:next_input()
  end
end

---Navigate to previous input
function FloatWindow:prev_input()
  if self._input_manager then
    self._input_manager:prev_input()
  end
end

---Get value of a specific input
---@param key string Input key
---@return string? value
function FloatWindow:get_input_value(key)
  if self._input_manager then
    return self._input_manager:get_value(key)
  end
  return nil
end

---Get all input values
---@return table<string, string> values Map of key -> value
function FloatWindow:get_all_input_values()
  if self._input_manager then
    return self._input_manager:get_all_values()
  end
  return {}
end

---Set value of a specific input
---@param key string Input key
---@param value string New value
function FloatWindow:set_input_value(key, value)
  if self._input_manager then
    self._input_manager:set_value(key, value)
  end
end

---Set callback for when input is submitted (Enter pressed in input mode)
---@param callback function Callback function to run on submit
function FloatWindow:on_input_submit(callback)
  if self._input_manager then
    self._input_manager.on_submit = callback
  end
end

-- ============================================================================
-- Scrollbar Support
-- ============================================================================

---Setup the scrollbar overlay window
function FloatWindow:_setup_scrollbar()
  if not self:is_valid() then return end

  local total_lines = #self.lines
  local win_height = self._win_height

  -- Guard against nil win_height
  if not win_height or win_height <= 0 then
    return
  end

  -- Only show scrollbar if content exceeds window height
  if total_lines <= win_height then
    return
  end

  -- Don't create duplicate scrollbar
  if self._scrollbar_winid and vim.api.nvim_win_is_valid(self._scrollbar_winid) then
    -- Just update existing scrollbar
    return
  end

  -- Create scrollbar buffer
  self._scrollbar_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(self._scrollbar_bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(self._scrollbar_bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(self._scrollbar_bufnr, 'swapfile', false)

  -- Calculate scrollbar position
  -- For editor-relative floats, the window row/col is where content starts
  -- Border is drawn around it visually but doesn't change the row/col values
  -- We want scrollbar at the rightmost column of the visible content area
  -- Add +1 to row to account for the top border
  local scrollbar_row = self._win_row + 1
  local scrollbar_col = self._win_col + self._win_width - 1  -- Last column of content area

  -- Create scrollbar window
  self._scrollbar_winid = vim.api.nvim_open_win(self._scrollbar_bufnr, false, {
    relative = "editor",
    width = 1,
    height = win_height,
    row = scrollbar_row,
    col = scrollbar_col,
    style = "minimal",
    focusable = false,
    zindex = (self.config.zindex or 50) + 1,  -- Above main window
  })

  -- Set scrollbar window options
  vim.api.nvim_set_option_value('winblend', self.config.winblend or 0, { win = self._scrollbar_winid })
  vim.api.nvim_set_option_value('winhighlight', 'Normal:SsnsScrollbar,NormalFloat:SsnsScrollbar', { win = self._scrollbar_winid })

  -- Initial scrollbar render
  self:_update_scrollbar()

  -- Setup autocmd to track scrolling in main window
  self._scrollbar_autocmd = vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinScrolled" }, {
    buffer = self.bufnr,
    callback = function()
      self:_update_scrollbar()
    end,
  })
end

---Update the scrollbar display based on current scroll position
function FloatWindow:_update_scrollbar()
  -- Guard against nil geometry (shouldn't happen but be safe)
  if not self._win_height or not self._win_width then
    return
  end

  local total_lines = #self.lines
  local win_height = self._win_height

  -- Don't show scrollbar if content fits
  if total_lines <= win_height then
    self:_close_scrollbar()
    return
  end

  -- Create scrollbar if it doesn't exist but should (content now exceeds window height)
  if not self._scrollbar_winid or not vim.api.nvim_win_is_valid(self._scrollbar_winid) then
    -- _setup_scrollbar will call _update_scrollbar at the end for rendering
    self:_setup_scrollbar()
    return
  end

  -- Get current scroll position
  local win_info = vim.fn.getwininfo(self.winid)[1]
  local top_line = win_info and win_info.topline or 1
  local bot_line = math.min(top_line + win_height - 1, total_lines)

  -- Build scrollbar content
  local scrollbar_lines = {}
  local track_height = win_height

  -- Determine if we can scroll up/down
  local can_scroll_up = top_line > 1
  local can_scroll_down = bot_line < total_lines

  -- Calculate thumb position and size within the track area (excluding arrow rows)
  -- Arrows are at row 1 and row track_height, so thumb lives in rows 2 to track_height-1
  local thumb_track_height = track_height - 2  -- Exclude top and bottom arrow rows
  
  if thumb_track_height < 1 then
    -- Window too small for thumb track, just show arrows
    for i = 1, track_height do
      if i == 1 then
        table.insert(scrollbar_lines, SCROLLBAR_CHARS.UP_ARROW)
      elseif i == track_height then
        table.insert(scrollbar_lines, SCROLLBAR_CHARS.DOWN_ARROW)
      else
        table.insert(scrollbar_lines, SCROLLBAR_CHARS.TRACK)
      end
    end
  else
    -- Calculate thumb size and position within the middle track
    local visible_ratio = win_height / total_lines
    local thumb_size = math.max(1, math.floor(thumb_track_height * visible_ratio))
    thumb_size = math.min(thumb_size, thumb_track_height)  -- Don't exceed track
    
    -- Calculate scroll position (0 to 1)
    local max_scroll = total_lines - win_height
    local scroll_ratio = max_scroll > 0 and (top_line - 1) / max_scroll or 0
    
    -- Calculate thumb start position within track (0-indexed within thumb_track)
    local thumb_start = math.floor(scroll_ratio * (thumb_track_height - thumb_size))
    thumb_start = math.max(0, math.min(thumb_start, thumb_track_height - thumb_size))

    for i = 1, track_height do
      local char
      if i == 1 then
        -- Top row - always show up arrow
        char = SCROLLBAR_CHARS.UP_ARROW
      elseif i == track_height then
        -- Bottom row - always show down arrow
        char = SCROLLBAR_CHARS.DOWN_ARROW
      else
        -- Middle rows (track area) - rows 2 to track_height-1
        -- Convert to 0-indexed position within thumb track
        local track_pos = i - 2  -- Row 2 becomes pos 0, row 3 becomes pos 1, etc.
        if track_pos >= thumb_start and track_pos < thumb_start + thumb_size then
          char = SCROLLBAR_CHARS.THUMB
        else
          char = SCROLLBAR_CHARS.TRACK
        end
      end
      table.insert(scrollbar_lines, char)
    end
  end

  -- Update scrollbar buffer
  vim.api.nvim_buf_set_option(self._scrollbar_bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(self._scrollbar_bufnr, 0, -1, false, scrollbar_lines)
  vim.api.nvim_buf_set_option(self._scrollbar_bufnr, 'modifiable', false)

  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace("ssns_scrollbar")
  vim.api.nvim_buf_clear_namespace(self._scrollbar_bufnr, ns_id, 0, -1)

  for i, char in ipairs(scrollbar_lines) do
    local hl_group
    if char == SCROLLBAR_CHARS.UP_ARROW or char == SCROLLBAR_CHARS.DOWN_ARROW then
      hl_group = "SsnsScrollbarArrow"
    elseif char == SCROLLBAR_CHARS.THUMB then
      hl_group = "SsnsScrollbarThumb"
    else
      hl_group = "SsnsScrollbarTrack"
    end
    vim.api.nvim_buf_add_highlight(self._scrollbar_bufnr, ns_id, hl_group, i - 1, 0, -1)
  end
end

---Close the scrollbar window
function FloatWindow:_close_scrollbar()
  -- Remove autocmd
  if self._scrollbar_autocmd then
    pcall(vim.api.nvim_del_autocmd, self._scrollbar_autocmd)
    self._scrollbar_autocmd = nil
  end

  -- Close scrollbar window
  if self._scrollbar_winid and vim.api.nvim_win_is_valid(self._scrollbar_winid) then
    vim.api.nvim_win_close(self._scrollbar_winid, true)
  end
  self._scrollbar_winid = nil

  -- Delete scrollbar buffer
  if self._scrollbar_bufnr and vim.api.nvim_buf_is_valid(self._scrollbar_bufnr) then
    vim.api.nvim_buf_delete(self._scrollbar_bufnr, { force = true })
  end
  self._scrollbar_bufnr = nil
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

-- ============================================================================
-- Multi-Panel Floating Window Support (with nested layouts)
-- ============================================================================

---@class MultiPanelConfig
---Configuration for multi-panel floating window
---@field layout LayoutNode Root layout node defining panel structure
---@field total_width_ratio number? Total width as ratio of screen (default: 0.85)
---@field total_height_ratio number? Total height as ratio of screen (default: 0.75)
---@field footer string? Footer text (shown below all panels)
---@field on_close function? Callback when window closes
---@field initial_focus string? Panel name to focus initially
---@field augroup_name string? Name for autocmd group

---@class LayoutNode
---A node in the layout tree - either a split or a panel
---@field split "horizontal"|"vertical"? Split direction (nil = leaf panel)
---@field ratio number? Size ratio relative to siblings (default: 1.0)
---@field children LayoutNode[]? Child nodes for splits
---@field name string? Panel name (required for leaf nodes)
---@field title string? Panel title
---@field filetype string? Filetype for syntax highlighting
---@field focusable boolean? Can this panel be focused (default: true)
---@field cursorline boolean? Show cursor line when focused (default: true)
---@field on_render fun(state: MultiPanelState): string[], table[]? Render callback
---@field on_focus fun(state: MultiPanelState)? Called when panel gains focus
---@field on_blur fun(state: MultiPanelState)? Called when panel loses focus

---@class MultiPanelState
---State object for multi-panel window
---@field panels table<string, PanelInfo> Map of panel name -> panel info
---@field panel_order string[] Ordered list of panel names (for tab navigation)
---@field focused_panel string Currently focused panel name
---@field footer_buf number? Footer buffer
---@field footer_win number? Footer window
---@field config MultiPanelConfig Original configuration
---@field data any Custom user data
---@field _augroup number? Autocmd group ID
---@field _closed boolean? Whether the window has been closed
---@field _layout_cache table? Cached layout calculations

---@class PanelInfo
---Information about a single panel
---@field float FloatWindow FloatWindow instance for this panel
---@field definition LayoutNode Panel definition
---@field rect LayoutRect Panel rectangle
---@field namespace number Highlight namespace (for panel-specific highlights)

---@class MultiPanelWindow
---Multi-panel floating window instance
local MultiPanelWindow = {}
MultiPanelWindow.__index = MultiPanelWindow

-- Box drawing characters
local BORDER_CHARS = {
  horizontal = "─",
  vertical = "│",
  top_left = "╭",
  top_right = "╮",
  bottom_left = "╰",
  bottom_right = "╯",
  t_down = "┬",  -- T pointing down (top edge with connection below)
  t_up = "┴",    -- T pointing up (bottom edge with connection above)
  t_right = "├", -- T pointing right (left edge with connection right)
  t_left = "┤",  -- T pointing left (right edge with connection left)
  cross = "┼",   -- 4-way intersection
}

---@class BorderPosition
---@field top boolean Has neighbor above
---@field bottom boolean Has neighbor below
---@field left boolean Has neighbor to the left
---@field right boolean Has neighbor to the right

---Create border for a panel based on its position in the layout
---@param pos BorderPosition Position flags
---@return table border Border characters
local function create_panel_border(pos)
  local c = BORDER_CHARS

  -- Determine corner characters based on neighbors
  local top_left, top_right, bottom_left, bottom_right

  -- Top-left corner
  if pos.top and pos.left then
    top_left = c.cross
  elseif pos.top then
    top_left = c.t_right
  elseif pos.left then
    top_left = c.t_down
  else
    top_left = c.top_left
  end

  -- Top-right corner
  if pos.top and pos.right then
    top_right = c.cross
  elseif pos.top then
    top_right = c.t_left
  elseif pos.right then
    top_right = c.t_down
  else
    top_right = c.top_right
  end

  -- Bottom-left corner
  if pos.bottom and pos.left then
    bottom_left = c.cross
  elseif pos.bottom then
    bottom_left = c.t_right
  elseif pos.left then
    bottom_left = c.t_up
  else
    bottom_left = c.bottom_left
  end

  -- Bottom-right corner
  if pos.bottom and pos.right then
    bottom_right = c.cross
  elseif pos.bottom then
    bottom_right = c.t_left
  elseif pos.right then
    bottom_right = c.t_up
  else
    bottom_right = c.bottom_right
  end

  return {
    top_left, c.horizontal, top_right,
    c.vertical, bottom_right, c.horizontal,
    bottom_left, c.vertical,
  }
end

---@class LayoutRect
---@field x number Left position
---@field y number Top position
---@field width number Width
---@field height number Height

---@class PanelLayout
---@field name string Panel name
---@field rect LayoutRect Panel rectangle
---@field border_pos BorderPosition Border position flags
---@field definition LayoutNode Panel definition

---Recursively calculate layout for a layout node
---@param node LayoutNode Layout node
---@param rect LayoutRect Available rectangle
---@param border_pos BorderPosition Inherited border position
---@param results PanelLayout[] Output array
---@param sibling_info table? Info about siblings {index, total, direction}
local function calculate_layout_recursive(node, rect, border_pos, results, sibling_info)
  if node.split then
    -- This is a split node - divide space among children
    local children = node.children or {}
    if #children == 0 then return end

    -- Calculate total ratio
    local total_ratio = 0
    for _, child in ipairs(children) do
      total_ratio = total_ratio + (child.ratio or 1.0)
    end

    if node.split == "horizontal" then
      -- Split horizontally (children side by side)
      local available_width = rect.width - (#children - 1)  -- Account for shared borders
      local current_x = rect.x

      for i, child in ipairs(children) do
        local child_ratio = (child.ratio or 1.0) / total_ratio
        local child_width = math.floor(available_width * child_ratio)

        -- Last child gets remaining width
        if i == #children then
          child_width = rect.x + rect.width - current_x
        end

        -- Calculate border position for child
        local child_border = {
          top = border_pos.top,
          bottom = border_pos.bottom,
          left = i > 1,           -- Has left neighbor if not first
          right = i < #children,  -- Has right neighbor if not last
        }

        local child_rect = {
          x = current_x,
          y = rect.y,
          width = child_width,
          height = rect.height,
        }

        calculate_layout_recursive(child, child_rect, child_border, results, {
          index = i,
          total = #children,
          direction = "horizontal",
        })

        current_x = current_x + child_width + 1  -- +1 for shared border
      end
    else
      -- Split vertically (children stacked)
      local available_height = rect.height - (#children - 1)  -- Account for shared borders
      local current_y = rect.y

      for i, child in ipairs(children) do
        local child_ratio = (child.ratio or 1.0) / total_ratio
        local child_height = math.floor(available_height * child_ratio)

        -- Last child gets remaining height
        if i == #children then
          child_height = rect.y + rect.height - current_y
        end

        -- Calculate border position for child
        local child_border = {
          top = i > 1,            -- Has top neighbor if not first
          bottom = i < #children, -- Has bottom neighbor if not last
          left = border_pos.left,
          right = border_pos.right,
        }

        local child_rect = {
          x = rect.x,
          y = current_y,
          width = rect.width,
          height = child_height,
        }

        calculate_layout_recursive(child, child_rect, child_border, results, {
          index = i,
          total = #children,
          direction = "vertical",
        })

        current_y = current_y + child_height + 1  -- +1 for shared border
      end
    end
  else
    -- This is a leaf panel
    table.insert(results, {
      name = node.name,
      rect = rect,
      border_pos = border_pos,
      definition = node,
    })
  end
end

---Calculate full layout from config
---@param config MultiPanelConfig Configuration
---@return PanelLayout[] layouts, number total_width, number total_height, number start_row, number start_col
local function calculate_full_layout(config)
  local width_ratio = config.total_width_ratio or 0.85
  local height_ratio = config.total_height_ratio or 0.75
  local total_width = math.floor(vim.o.columns * width_ratio)
  local total_height = math.floor(vim.o.lines * height_ratio)
  local start_row = math.floor((vim.o.lines - total_height) / 2)
  local start_col = math.floor((vim.o.columns - total_width) / 2)

  local results = {}
  local root_rect = {
    x = start_col,
    y = start_row,
    width = total_width,
    height = total_height,
  }

  calculate_layout_recursive(config.layout, root_rect, {
    top = false,
    bottom = false,
    left = false,
    right = false,
  }, results, nil)

  return results, total_width, total_height, start_row, start_col
end

---Collect panel names in order (for tab navigation)
---@param node LayoutNode Layout node
---@param result string[] Output array
local function collect_panel_names(node, result)
  if node.split then
    for _, child in ipairs(node.children or {}) do
      collect_panel_names(child, result)
    end
  elseif node.name then
    table.insert(result, node.name)
  end
end

---Create a multi-panel floating window
---@param config MultiPanelConfig Configuration
---@return MultiPanelState? state State object (nil if creation failed)
function UiFloat.create_multi_panel(config)
  if not config.layout then
    vim.notify("SSNS: Layout configuration is required", vim.log.levels.ERROR)
    return nil
  end

  -- Calculate layouts
  local layouts, total_width, total_height, start_row, start_col = calculate_full_layout(config)

  if #layouts == 0 then
    vim.notify("SSNS: No panels defined in layout", vim.log.levels.ERROR)
    return nil
  end

  -- Collect panel names for tab navigation
  local panel_order = {}
  collect_panel_names(config.layout, panel_order)

  -- Determine initial focus
  local initial_focus = config.initial_focus
  if not initial_focus and #panel_order > 0 then
    initial_focus = panel_order[1]
  end

  -- Create state
  local state = setmetatable({
    panels = {},
    panel_order = panel_order,
    focused_panel = initial_focus,
    footer_buf = nil,
    footer_win = nil,
    config = config,
    data = {},
    _closed = false,
    _layout_cache = {
      total_width = total_width,
      total_height = total_height,
      start_row = start_row,
      start_col = start_col,
    },
  }, MultiPanelWindow)

  -- Create panels using FloatWindow
  for _, panel_layout in ipairs(layouts) do
    local def = panel_layout.definition
    local rect = panel_layout.rect
    local border = create_panel_border(panel_layout.border_pos)

    -- Create FloatWindow for this panel with explicit positioning
    local float = UiFloat.create({}, {
      -- Explicit positioning (no auto-calc, no centering)
      centered = false,
      width = rect.width,
      height = rect.height,
      row = rect.y,
      col = rect.x,
      -- Panel configuration
      title = def.title,
      border = border,
      filetype = def.filetype,
      focusable = def.focusable ~= false,
      -- Don't enter panel windows on create, don't add default keymaps
      enter = false,
      default_keymaps = false,
      -- Start with cursorline disabled (focus_panel will enable it)
      cursorline = false,
      -- Scrollbar support
      scrollbar = true,
      -- Standard panel options
      modifiable = false,
      readonly = true,
    })

    -- Store panel info with FloatWindow instance
    state.panels[def.name] = {
      float = float,
      definition = def,
      rect = rect,
      namespace = vim.api.nvim_create_namespace("ssns_panel_" .. def.name),
    }
  end

  -- Create footer if specified
  if config.footer then
    state.footer_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.footer_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(state.footer_buf, 'modifiable', false)

    -- Center the footer text
    local footer_text = config.footer
    local text_len = vim.fn.strdisplaywidth(footer_text)
    local padding = math.floor((total_width - text_len) / 2)
    local centered_text = string.rep(" ", math.max(0, padding)) .. footer_text

    vim.api.nvim_buf_set_option(state.footer_buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(state.footer_buf, 0, -1, false, {centered_text})
    vim.api.nvim_buf_set_option(state.footer_buf, 'modifiable', false)

    state.footer_win = vim.api.nvim_open_win(state.footer_buf, false, {
      relative = "editor",
      width = total_width,
      height = 1,
      row = start_row + total_height + 2,
      col = start_col,
      style = "minimal",
      border = "none",
      zindex = 52,
      focusable = false,
    })

    -- Style footer with themed hint color
    vim.api.nvim_set_option_value('winhighlight', 'Normal:SsnsFloatHint', { win = state.footer_win })
  end

  -- Focus initial panel
  state:focus_panel(state.focused_panel)

  -- Setup autocmds
  state:_setup_autocmds()

  return state
end

---Focus a specific panel
---@param panel_name string Panel to focus
function MultiPanelWindow:focus_panel(panel_name)
  if self._closed then return end

  local panel = self.panels[panel_name]
  if not panel or panel.definition.focusable == false then
    return
  end

  -- Call blur on current panel
  local current_panel = self.panels[self.focused_panel]
  if current_panel and current_panel.definition.name ~= panel_name then
    -- Disable cursorline on previous panel
    if current_panel.float:is_valid() then
      vim.api.nvim_set_option_value('cursorline', false, { win = current_panel.float.winid })
    end
    if current_panel.definition.on_blur then
      current_panel.definition.on_blur(self)
    end
  end

  -- Update focused panel
  self.focused_panel = panel_name

  -- Focus the window and enable cursorline
  if panel.float:is_valid() then
    vim.api.nvim_set_current_win(panel.float.winid)
    if panel.definition.cursorline ~= false then
      vim.api.nvim_set_option_value('cursorline', true, { win = panel.float.winid })
    end
  end

  -- Call focus callback
  if panel.definition.on_focus then
    panel.definition.on_focus(self)
  end
end

---Focus next panel in order
function MultiPanelWindow:focus_next_panel()
  if self._closed then return end

  local current_idx = 1
  for i, name in ipairs(self.panel_order) do
    if name == self.focused_panel then
      current_idx = i
      break
    end
  end

  -- Find next focusable panel
  for offset = 1, #self.panel_order do
    local next_idx = ((current_idx - 1 + offset) % #self.panel_order) + 1
    local next_name = self.panel_order[next_idx]
    local next_panel = self.panels[next_name]
    if next_panel and next_panel.definition.focusable ~= false then
      self:focus_panel(next_name)
      return
    end
  end
end

---Focus previous panel in order
function MultiPanelWindow:focus_prev_panel()
  if self._closed then return end

  local current_idx = 1
  for i, name in ipairs(self.panel_order) do
    if name == self.focused_panel then
      current_idx = i
      break
    end
  end

  -- Find previous focusable panel
  for offset = 1, #self.panel_order do
    local prev_idx = ((current_idx - 1 - offset) % #self.panel_order) + 1
    local prev_name = self.panel_order[prev_idx]
    local prev_panel = self.panels[prev_name]
    if prev_panel and prev_panel.definition.focusable ~= false then
      self:focus_panel(prev_name)
      return
    end
  end
end

---Render a specific panel
---@param panel_name string Panel to render
function MultiPanelWindow:render_panel(panel_name)
  if self._closed then return end

  local panel = self.panels[panel_name]
  if not panel or not panel.float:is_valid() then return end

  local def = panel.definition
  if not def.on_render then return end

  -- Call render callback
  local lines, highlights = def.on_render(self)
  lines = lines or {}
  highlights = highlights or {}

  -- Update buffer content using FloatWindow (handles scrollbar automatically)
  panel.float:update_lines(lines)

  -- Apply panel-specific highlights
  vim.api.nvim_buf_clear_namespace(panel.float.bufnr, panel.namespace, 0, -1)
  for _, hl in ipairs(highlights) do
    -- Support both array format {line, col_start, col_end, hl_group} 
    -- and named format {line=, col_start=, col_end=, hl_group=} from ContentBuilder
    local line = hl.line or hl[1]
    local col_start = hl.col_start or hl[2]
    local col_end = hl.col_end or hl[3]
    local hl_group = hl.hl_group or hl[4]
    
    if line and col_start and col_end and hl_group then
      vim.api.nvim_buf_add_highlight(
        panel.float.bufnr, panel.namespace,
        hl_group, line, col_start, col_end
      )
    end
  end
end

---Render all panels
function MultiPanelWindow:render_all()
  for name, _ in pairs(self.panels) do
    self:render_panel(name)
  end
end

---Update panel title
---@param panel_name string Panel name
---@param title string New title
function MultiPanelWindow:update_panel_title(panel_name, title)
  if self._closed then return end

  local panel = self.panels[panel_name]
  if not panel or not panel.float:is_valid() then
    return
  end

  vim.api.nvim_win_set_config(panel.float.winid, {
    title = string.format(" %s ", title),
    title_pos = "center",
  })
end

---Get panel buffer
---@param panel_name string Panel name
---@return number? bufnr Buffer number or nil
function MultiPanelWindow:get_panel_buffer(panel_name)
  local panel = self.panels[panel_name]
  return panel and panel.float and panel.float.bufnr or nil
end

---Get panel window
---@param panel_name string Panel name
---@return number? winid Window ID or nil
function MultiPanelWindow:get_panel_window(panel_name)
  local panel = self.panels[panel_name]
  return panel and panel.float and panel.float.winid or nil
end

---Get the FloatWindow instance for a panel
---@param panel_name string Panel name
---@return FloatWindow? float FloatWindow instance or nil
function MultiPanelWindow:get_panel_float(panel_name)
  local panel = self.panels[panel_name]
  return panel and panel.float or nil
end

---Set cursor in panel
---@param panel_name string Panel name
---@param row number Row (1-indexed)
---@param col number? Column (0-indexed, default 0)
function MultiPanelWindow:set_cursor(panel_name, row, col)
  if self._closed then return end

  local panel = self.panels[panel_name]
  if panel and panel.float:is_valid() then
    panel.float:set_cursor(row, col or 0)
  end
end

---Get cursor position in panel
---@param panel_name string Panel name
---@return number row, number col
function MultiPanelWindow:get_cursor(panel_name)
  local panel = self.panels[panel_name]
  if panel and panel.float:is_valid() then
    return panel.float:get_cursor()
  end
  return 1, 0
end

---Setup keymaps for all panels
---@param keymaps table<string, function> Keymaps to set on all focusable panels
function MultiPanelWindow:set_keymaps(keymaps)
  for name, panel in pairs(self.panels) do
    if panel.definition.focusable ~= false and panel.float:is_valid() then
      for lhs, handler in pairs(keymaps) do
        vim.keymap.set('n', lhs, handler, {
          buffer = panel.float.bufnr,
          noremap = true,
          silent = true,
        })
      end
    end
  end
end

---Setup keymaps for a specific panel
---@param panel_name string Panel name
---@param keymaps table<string, function> Keymaps to set
function MultiPanelWindow:set_panel_keymaps(panel_name, keymaps)
  local panel = self.panels[panel_name]
  if not panel or not panel.float:is_valid() then return end

  for lhs, handler in pairs(keymaps) do
    vim.keymap.set('n', lhs, handler, {
      buffer = panel.float.bufnr,
      noremap = true,
      silent = true,
    })
  end
end

---Setup autocmds for cleanup and resize
function MultiPanelWindow:_setup_autocmds()
  local augroup_name = self.config.augroup_name or ("SSNSMultiPanel_" .. tostring(os.time()))
  self._augroup = vim.api.nvim_create_augroup(augroup_name, { clear = true })

  -- Close when any panel window is closed
  for name, panel in pairs(self.panels) do
    vim.api.nvim_create_autocmd("WinClosed", {
      group = self._augroup,
      pattern = tostring(panel.float.winid),
      once = true,
      callback = function()
        self:close()
      end,
    })
  end

  -- Handle terminal resize
  vim.api.nvim_create_autocmd("VimResized", {
    group = self._augroup,
    callback = function()
      if not self._closed then
        self:_recalculate_layout()
      end
    end,
  })
end

---Recalculate layout after resize
function MultiPanelWindow:_recalculate_layout()
  if self._closed then return end

  -- Calculate new layouts
  local layouts, total_width, total_height, start_row, start_col = calculate_full_layout(self.config)

  -- Update cache
  self._layout_cache = {
    total_width = total_width,
    total_height = total_height,
    start_row = start_row,
    start_col = start_col,
  }

  -- Update panel windows
  for _, panel_layout in ipairs(layouts) do
    local panel = self.panels[panel_layout.name]
    local rect = panel_layout.rect
    local border = create_panel_border(panel_layout.border_pos)

    if panel and panel.float:is_valid() then
      -- Update stored rect
      panel.rect = rect
      -- Update FloatWindow's stored geometry for scrollbar
      panel.float._win_row = rect.y
      panel.float._win_col = rect.x
      panel.float._win_width = rect.width
      panel.float._win_height = rect.height
      
      vim.api.nvim_win_set_config(panel.float.winid, {
        relative = "editor",
        width = rect.width,
        height = rect.height,
        row = rect.y,
        col = rect.x,
        border = border,
      })
    end
  end

  -- Update footer if present
  if self.footer_win and vim.api.nvim_win_is_valid(self.footer_win) then
    -- Recenter footer text
    if self.footer_buf and vim.api.nvim_buf_is_valid(self.footer_buf) then
      local footer_text = self.config.footer or ""
      local text_len = vim.fn.strdisplaywidth(footer_text)
      local padding = math.floor((total_width - text_len) / 2)
      local centered_text = string.rep(" ", math.max(0, padding)) .. footer_text

      vim.api.nvim_buf_set_option(self.footer_buf, 'modifiable', true)
      vim.api.nvim_buf_set_lines(self.footer_buf, 0, -1, false, {centered_text})
      vim.api.nvim_buf_set_option(self.footer_buf, 'modifiable', false)
    end

    vim.api.nvim_win_set_config(self.footer_win, {
      relative = "editor",
      width = total_width,
      height = 1,
      row = start_row + total_height + 2,
      col = start_col,
    })
  end
end

---Check if multi-panel window is valid
---@return boolean
function MultiPanelWindow:is_valid()
  if self._closed then return false end

  -- Check if any panel FloatWindow is valid
  for _, panel in pairs(self.panels) do
    if panel.float and panel.float:is_valid() then
      return true
    end
  end
  return false
end

-- ============================================================================
-- Input Field Support for MultiPanelWindow
-- ============================================================================

---Setup input fields for a panel from a ContentBuilder
---@param panel_name string Panel name
---@param content_builder ContentBuilder ContentBuilder instance with inputs
---@param opts table? Options: { on_value_change = function?, on_input_enter = function?, on_input_exit = function? }
function MultiPanelWindow:setup_inputs(panel_name, content_builder, opts)
  if self._closed then return end
  opts = opts or {}

  local panel = self.panels[panel_name]
  if not panel or not panel.float:is_valid() then return end

  local inputs = content_builder:get_inputs()
  local input_order = content_builder:get_input_order()

  -- Skip if no inputs
  if vim.tbl_isempty(inputs) then return end

  -- Create input manager for this panel using FloatWindow's bufnr/winid
  local InputManager = require('ssns.ui.core.input_manager')
  
  panel.input_manager = InputManager.new({
    bufnr = panel.float.bufnr,
    winid = panel.float.winid,
    inputs = inputs,
    input_order = input_order,
    on_value_change = opts.on_value_change,
    on_input_enter = opts.on_input_enter,
    on_input_exit = opts.on_input_exit,
  })

  panel.input_manager:setup()
end

---Get the value of an input field in a panel
---@param panel_name string Panel name
---@param input_key string Input key
---@return string? value
function MultiPanelWindow:get_input_value(panel_name, input_key)
  local panel = self.panels[panel_name]
  if panel and panel.input_manager then
    return panel.input_manager:get_value(input_key)
  end
  return nil
end

---Get all input values from a panel
---@param panel_name string Panel name
---@return table<string, string>? values Map of input key -> value
function MultiPanelWindow:get_all_input_values(panel_name)
  local panel = self.panels[panel_name]
  if panel and panel.input_manager then
    return panel.input_manager:get_all_values()
  end
  return nil
end

---Set the value of an input field in a panel
---@param panel_name string Panel name
---@param input_key string Input key
---@param value string New value
function MultiPanelWindow:set_input_value(panel_name, input_key, value)
  local panel = self.panels[panel_name]
  if panel and panel.input_manager then
    panel.input_manager:set_value(input_key, value)
  end
end

---Enter input mode for a specific input in a panel
---@param panel_name string Panel name
---@param input_key string Input key to activate
function MultiPanelWindow:enter_input(panel_name, input_key)
  local panel = self.panels[panel_name]
  if panel and panel.input_manager then
    -- Focus the panel first
    self:focus_panel(panel_name)
    panel.input_manager:enter_input_mode(input_key)
  end
end

---Update input definitions for a panel (after re-render)
---@param panel_name string Panel name
---@param content_builder ContentBuilder New ContentBuilder with updated inputs
function MultiPanelWindow:update_inputs(panel_name, content_builder)
  local panel = self.panels[panel_name]
  if panel and panel.input_manager then
    local inputs = content_builder:get_inputs()
    local input_order = content_builder:get_input_order()
    panel.input_manager:update_inputs(inputs, input_order)
  end
end

---Close the multi-panel window
function MultiPanelWindow:close()
  if self._closed then return end
  self._closed = true

  -- Call on_close callback
  if self.config.on_close then
    pcall(self.config.on_close, self)
  end

  -- Cleanup input managers and close FloatWindows (handles scrollbar cleanup)
  for _, panel in pairs(self.panels) do
    if panel.input_manager then
      pcall(function() panel.input_manager:destroy() end)
    end
    -- Close FloatWindow (handles scrollbar and window cleanup)
    if panel.float then
      pcall(function() panel.float:close() end)
    end
  end

  -- Close footer
  if self.footer_win and vim.api.nvim_win_is_valid(self.footer_win) then
    pcall(vim.api.nvim_win_close, self.footer_win, true)
  end
  if self.footer_buf and vim.api.nvim_buf_is_valid(self.footer_buf) then
    pcall(vim.api.nvim_buf_delete, self.footer_buf, { force = true })
  end

  -- Clear autocmds
  if self._augroup then
    pcall(vim.api.nvim_del_augroup_by_id, self._augroup)
  end
end

return UiFloat
