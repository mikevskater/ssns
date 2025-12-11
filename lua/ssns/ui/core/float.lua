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
---@field bufnr number Buffer handle
---@field winid number Window handle
---@field namespace number Highlight namespace
---@field definition LayoutNode Panel definition

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

  -- Create panels
  for _, panel_layout in ipairs(layouts) do
    local def = panel_layout.definition
    local rect = panel_layout.rect
    local border = create_panel_border(panel_layout.border_pos)

    -- Create buffer
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)

    if def.filetype then
      vim.api.nvim_buf_set_option(bufnr, 'filetype', def.filetype)
    end

    -- Create window
    local win_opts = {
      relative = "editor",
      width = rect.width,
      height = rect.height,
      row = rect.y,
      col = rect.x,
      style = "minimal",
      border = border,
      zindex = 50,
      focusable = def.focusable ~= false,
    }

    if def.title then
      win_opts.title = string.format(" %s ", def.title)
      win_opts.title_pos = "center"
    end

    local winid = vim.api.nvim_open_win(bufnr, false, win_opts)

    -- Configure window options with themed highlights
    vim.api.nvim_set_option_value('number', false, { win = winid })
    vim.api.nvim_set_option_value('relativenumber', false, { win = winid })
    vim.api.nvim_set_option_value('wrap', false, { win = winid })
    vim.api.nvim_set_option_value('signcolumn', 'no', { win = winid })
    vim.api.nvim_set_option_value('winhighlight',
      'Normal:Normal,FloatBorder:SsnsFloatBorder,FloatTitle:SsnsFloatTitle,CursorLine:SsnsFloatSelected',
      { win = winid }
    )

    -- Cursorline only on focusable panels (start disabled, focus_panel will enable)
    vim.api.nvim_set_option_value('cursorline', false, { win = winid })

    -- Store panel info
    state.panels[def.name] = {
      bufnr = bufnr,
      winid = winid,
      namespace = vim.api.nvim_create_namespace("ssns_panel_" .. def.name),
      definition = def,
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
    if vim.api.nvim_win_is_valid(current_panel.winid) then
      vim.api.nvim_set_option_value('cursorline', false, { win = current_panel.winid })
    end
    if current_panel.definition.on_blur then
      current_panel.definition.on_blur(self)
    end
  end

  -- Update focused panel
  self.focused_panel = panel_name

  -- Focus the window and enable cursorline
  if vim.api.nvim_win_is_valid(panel.winid) then
    vim.api.nvim_set_current_win(panel.winid)
    if panel.definition.cursorline ~= false then
      vim.api.nvim_set_option_value('cursorline', true, { win = panel.winid })
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
  if not panel then return end

  local def = panel.definition
  if not def.on_render then return end

  -- Call render callback
  local lines, highlights = def.on_render(self)
  lines = lines or {}
  highlights = highlights or {}

  -- Update buffer content
  if vim.api.nvim_buf_is_valid(panel.bufnr) then
    vim.api.nvim_buf_set_option(panel.bufnr, 'modifiable', true)
    vim.api.nvim_buf_set_lines(panel.bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(panel.bufnr, 'modifiable', false)

    -- Apply highlights
    vim.api.nvim_buf_clear_namespace(panel.bufnr, panel.namespace, 0, -1)
    for _, hl in ipairs(highlights) do
      -- hl format: {line, col_start, col_end, hl_group}
      vim.api.nvim_buf_add_highlight(
        panel.bufnr, panel.namespace,
        hl[4], hl[1], hl[2], hl[3]
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
  if not panel or not vim.api.nvim_win_is_valid(panel.winid) then
    return
  end

  vim.api.nvim_win_set_config(panel.winid, {
    title = string.format(" %s ", title),
    title_pos = "center",
  })
end

---Get panel buffer
---@param panel_name string Panel name
---@return number? bufnr Buffer number or nil
function MultiPanelWindow:get_panel_buffer(panel_name)
  local panel = self.panels[panel_name]
  return panel and panel.bufnr or nil
end

---Get panel window
---@param panel_name string Panel name
---@return number? winid Window ID or nil
function MultiPanelWindow:get_panel_window(panel_name)
  local panel = self.panels[panel_name]
  return panel and panel.winid or nil
end

---Set cursor in panel
---@param panel_name string Panel name
---@param row number Row (1-indexed)
---@param col number? Column (0-indexed, default 0)
function MultiPanelWindow:set_cursor(panel_name, row, col)
  if self._closed then return end

  local panel = self.panels[panel_name]
  if panel and vim.api.nvim_win_is_valid(panel.winid) then
    -- Ensure row is within buffer bounds
    local line_count = vim.api.nvim_buf_line_count(panel.bufnr)
    row = math.max(1, math.min(row, line_count))
    pcall(vim.api.nvim_win_set_cursor, panel.winid, {row, col or 0})
  end
end

---Get cursor position in panel
---@param panel_name string Panel name
---@return number row, number col
function MultiPanelWindow:get_cursor(panel_name)
  local panel = self.panels[panel_name]
  if panel and vim.api.nvim_win_is_valid(panel.winid) then
    local pos = vim.api.nvim_win_get_cursor(panel.winid)
    return pos[1], pos[2]
  end
  return 1, 0
end

---Setup keymaps for all panels
---@param keymaps table<string, function> Keymaps to set on all focusable panels
function MultiPanelWindow:set_keymaps(keymaps)
  for name, panel in pairs(self.panels) do
    if panel.definition.focusable ~= false then
      for lhs, handler in pairs(keymaps) do
        vim.keymap.set('n', lhs, handler, {
          buffer = panel.bufnr,
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
  if not panel then return end

  for lhs, handler in pairs(keymaps) do
    vim.keymap.set('n', lhs, handler, {
      buffer = panel.bufnr,
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
      pattern = tostring(panel.winid),
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

    if panel and vim.api.nvim_win_is_valid(panel.winid) then
      vim.api.nvim_win_set_config(panel.winid, {
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

  -- Check if any panel window is valid
  for _, panel in pairs(self.panels) do
    if vim.api.nvim_win_is_valid(panel.winid) then
      return true
    end
  end
  return false
end

---Close the multi-panel window
function MultiPanelWindow:close()
  if self._closed then return end
  self._closed = true

  -- Call on_close callback
  if self.config.on_close then
    pcall(self.config.on_close, self)
  end

  -- Close all panel windows
  for _, panel in pairs(self.panels) do
    if panel.winid and vim.api.nvim_win_is_valid(panel.winid) then
      pcall(vim.api.nvim_win_close, panel.winid, true)
    end
  end

  -- Close footer
  if self.footer_win and vim.api.nvim_win_is_valid(self.footer_win) then
    pcall(vim.api.nvim_win_close, self.footer_win, true)
  end

  -- Clear autocmds
  if self._augroup then
    pcall(vim.api.nvim_del_augroup_by_id, self._augroup)
  end
end

return UiFloat
