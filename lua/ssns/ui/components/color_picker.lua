---@class ColorPicker
---Interactive color picker with HSL grid navigation
local ColorPicker = {}

local ColorUtils = require('ssns.ui.components.color_utils')

-- ============================================================================
-- Types
-- ============================================================================

---@class ColorPickerColor
---@field fg string? Foreground hex color
---@field bg string? Background hex color
---@field bold boolean?
---@field italic boolean?
---@field underline boolean?

---@class ColorPickerOptions
---@field initial ColorPickerColor Initial color value
---@field title string? Title for the picker (e.g., color key name)
---@field on_change fun(color: ColorPickerColor)? Called on every navigation
---@field on_select fun(color: ColorPickerColor)? Called when user confirms
---@field on_cancel fun()? Called when user cancels

---@class ColorPickerState
---@field current ColorPickerColor Current working color
---@field original ColorPickerColor Original color for reset
---@field editing_bg boolean Whether editing background instead of foreground
---@field grid_width number Current grid width
---@field grid_height number Current grid height
---@field win number? Window handle
---@field buf number? Buffer handle
---@field ns number Namespace for highlights
---@field options ColorPickerOptions
---@field saved_hsl table? Saved HSL for when at white/black extremes
---@field help_win number? Help popup window handle
---@field help_buf number? Help popup buffer handle
---@field step_index number Index into STEP_SIZES array
---@field lightness_virtual number? Virtual lightness position (can exceed 0-100 for bounce)
---@field saturation_virtual number? Virtual saturation position (can exceed 0-100 for bounce)

-- ============================================================================
-- Constants
-- ============================================================================

local PREVIEW_HEIGHT = 2    -- Rows for color preview
local FOOTER_HEIGHT = 2     -- Rows for info and help hint
local HEADER_HEIGHT = 2     -- Title + blank line
local PADDING = 2           -- Left/right padding

local BASE_STEP_HUE = 3          -- Base hue degrees per grid cell
local BASE_STEP_LIGHTNESS = 2    -- Base lightness percent per grid row
local BASE_STEP_SATURATION = 2   -- Base saturation percent per J/K press

-- Step size multipliers (index 3 is default 1x)
local STEP_SIZES = { 0.25, 0.5, 1, 2, 4, 8 }
local STEP_LABELS = { "¼×", "½×", "1×", "2×", "4×", "8×" }
local DEFAULT_STEP_INDEX = 3  -- 1x multiplier

-- ============================================================================
-- State
-- ============================================================================

---@type ColorPickerState?
local state = nil

-- ============================================================================
-- Helpers
-- ============================================================================

---Get the active color (fg or bg based on editing mode)
---@return string hex
local function get_active_color()
  if not state then return "#808080" end
  if state.editing_bg then
    return state.current.bg or "#1E1E1E"
  else
    return state.current.fg or "#FFFFFF"
  end
end

---Set the active color
---@param hex string
local function set_active_color(hex)
  if not state then return end
  hex = ColorUtils.normalize_hex(hex)
  if state.editing_bg then
    state.current.bg = hex
  else
    state.current.fg = hex
  end
end

---Get current step multiplier
---@return number
local function get_step_multiplier()
  if not state then return 1 end
  return STEP_SIZES[state.step_index] or 1
end

---Get current step label
---@return string
local function get_step_label()
  if not state then return "1×" end
  return STEP_LABELS[state.step_index] or "1×"
end

---Map a virtual position to actual 0-100 value with bounce (triangular wave)
---Virtual position can exceed 0-100, bouncing at boundaries
---This allows continuous scrolling: colors go 0→100→0→100...
---@param virtual number Virtual position (unbounded)
---@return number actual Actual value (0-100)
local function virtual_to_actual(virtual)
  -- Triangular wave with period 200
  -- 0-100: ascending (0→100)
  -- 100-200: descending (100→0)
  -- 200-300: ascending (0→100)
  -- etc.
  local period = 200
  local normalized = virtual % period
  -- Handle negative modulo
  if normalized < 0 then normalized = normalized + period end

  if normalized <= 100 then
    return normalized
  else
    return 200 - normalized
  end
end

---Calculate grid dimensions based on window size
---@param win_width number
---@param win_height number
---@return number grid_width, number grid_height
local function calculate_grid_size(win_width, win_height)
  local available_width = win_width - PADDING * 2
  local available_height = win_height - HEADER_HEIGHT - PREVIEW_HEIGHT - FOOTER_HEIGHT - 2 -- 2 for borders around preview

  -- Ensure odd numbers for center alignment
  if available_width % 2 == 0 then available_width = available_width - 1 end
  if available_height % 2 == 0 then available_height = available_height - 1 end

  -- Minimum sizes
  available_width = math.max(11, available_width)
  available_height = math.max(5, available_height)

  return available_width, available_height
end

---Generate highlight group name for a grid cell
---@param row number
---@param col number
---@return string
local function get_cell_hl_group(row, col)
  return string.format("ColorPickerCell_%d_%d", row, col)
end

-- ============================================================================
-- Rendering
-- ============================================================================

---Create highlight groups for the color grid
---@param grid string[][] The color grid
local function create_grid_highlights(grid)
  if not state then return end

  local center_row = math.ceil(#grid / 2)
  local center_col = math.ceil(#grid[1] / 2)

  for row_idx, row in ipairs(grid) do
    for col_idx, color in ipairs(row) do
      local hl_name = get_cell_hl_group(row_idx, col_idx)
      local hl_def = { bg = color }

      -- Center cell gets contrasting foreground for the X marker
      if row_idx == center_row and col_idx == center_col then
        hl_def.fg = ColorUtils.get_contrast_color(color)
        hl_def.bold = true
      end

      vim.api.nvim_set_hl(0, hl_name, hl_def)
    end
  end
end

---Generate color grid with virtual lightness positions for continuous scrolling
---Each row uses virtual_to_actual to map virtual lightness to actual lightness
---This allows the grid to show continuous bounce pattern as user scrolls
---@return string[][] grid 2D array of hex colors [row][col]
local function generate_virtual_grid()
  if not state then return {} end

  local center_color = get_active_color()
  local h, s, l = ColorUtils.hex_to_hsl(center_color)

  -- Only use saved hue/saturation when at lightness extremes
  -- (where the current color's hue/sat become unreliable due to white/black)
  -- Otherwise use the current color's hue/sat to reflect user changes
  if state.saved_hsl and (l < 2 or l > 98) then
    h = state.saved_hsl.h
    s = state.saved_hsl.s
  end

  -- Get the virtual lightness position (initialize if needed)
  local virtual_l = state.lightness_virtual or l

  local grid = {}
  local half_height = math.floor(state.grid_height / 2)
  local half_width = math.floor(state.grid_width / 2)
  local hue_step = BASE_STEP_HUE * get_step_multiplier()
  local lightness_step = BASE_STEP_LIGHTNESS * get_step_multiplier()

  for row = 1, state.grid_height do
    local row_colors = {}
    -- Calculate virtual lightness for this row
    -- Top rows have higher virtual positions, bottom rows have lower
    local row_offset = half_height + 1 - row
    local row_virtual_l = virtual_l + (row_offset * lightness_step)
    -- Map virtual to actual using bounce
    local row_actual_l = virtual_to_actual(row_virtual_l)

    for col = 1, state.grid_width do
      -- Hue varies by column (left = lower hue, right = higher hue)
      local col_offset = col - half_width - 1
      local cell_h = (h + col_offset * hue_step) % 360
      if cell_h < 0 then cell_h = cell_h + 360 end

      local color = ColorUtils.hsl_to_hex(cell_h, s, row_actual_l)
      table.insert(row_colors, color)
    end

    table.insert(grid, row_colors)
  end

  return grid
end

---Render the color grid to buffer
---@return string[] lines
---@return table[] highlights
local function render_grid()
  if not state then return {}, {} end

  local lines = {}
  local highlights = {}

  -- Generate grid using virtual positions for continuous scrolling
  local grid = generate_virtual_grid()

  -- Create highlight groups
  create_grid_highlights(grid)

  local center_row = math.ceil(#grid / 2)
  local center_col = math.ceil(#grid[1] / 2)

  -- Padding string
  local pad = string.rep(" ", PADDING)

  for row_idx, row in ipairs(grid) do
    local line_chars = {}
    local line_hls = {}

    for col_idx, _ in ipairs(row) do
      local char = " "
      -- Center cell gets X marker
      if row_idx == center_row and col_idx == center_col then
        char = "X"
      end
      table.insert(line_chars, char)

      -- Store highlight info
      table.insert(line_hls, {
        col_start = PADDING + col_idx - 1,
        col_end = PADDING + col_idx,
        hl_group = get_cell_hl_group(row_idx, col_idx),
      })
    end

    local line = pad .. table.concat(line_chars)
    table.insert(lines, line)

    -- Add highlights for this line
    for _, hl in ipairs(line_hls) do
      table.insert(highlights, {
        line = #lines - 1, -- 0-indexed
        col_start = hl.col_start,
        col_end = hl.col_end,
        hl_group = hl.hl_group,
      })
    end
  end

  return lines, highlights
end

---Render the preview section
---@return string[] lines
---@return table[] highlights
local function render_preview()
  if not state then return {}, {} end

  local lines = {}
  local highlights = {}
  local pad = string.rep(" ", PADDING)

  -- Create preview highlight
  local preview_color = get_active_color()
  vim.api.nvim_set_hl(0, "ColorPickerPreview", { bg = preview_color })

  -- Preview border
  local preview_width = state.grid_width
  table.insert(lines, pad .. string.rep("─", preview_width))

  -- Preview rows (filled with spaces using background color)
  for i = 1, PREVIEW_HEIGHT do
    local preview_line = pad .. string.rep(" ", preview_width)
    table.insert(lines, preview_line)
    table.insert(highlights, {
      line = #lines - 1,
      col_start = PADDING,
      col_end = PADDING + preview_width,
      hl_group = "ColorPickerPreview",
    })
  end

  table.insert(lines, pad .. string.rep("─", preview_width))

  return lines, highlights
end

---Render the info footer
---@return string[] lines
---@return table[] highlights
local function render_footer()
  if not state then return {}, {} end

  local lines = {}
  local highlights = {}
  local pad = string.rep(" ", PADDING)

  -- Get colors
  local orig_color = state.editing_bg
    and (state.original.bg or "none")
    or (state.original.fg or "none")
  local curr_color = get_active_color()

  -- Create highlight groups for Original and Current preview text
  local orig_hl_name = "ColorPickerOriginalPreview"
  local curr_hl_name = "ColorPickerCurrentPreview"

  if orig_color ~= "none" then
    vim.api.nvim_set_hl(0, orig_hl_name, {
      fg = state.original.fg,
      bg = state.original.bg,
      bold = state.original.bold,
      italic = state.original.italic,
    })
  else
    vim.api.nvim_set_hl(0, orig_hl_name, { fg = "#808080", italic = true })
  end

  vim.api.nvim_set_hl(0, curr_hl_name, {
    fg = state.current.fg,
    bg = state.current.bg,
    bold = state.current.bold,
    italic = state.current.italic,
  })

  -- Mode and style indicators
  local mode = state.editing_bg and "[bg]" or "[fg]"
  local bold_indicator = state.current.bold and "[B]" or "[ ]"
  local italic_indicator = state.current.italic and "[I]" or "[ ]"

  table.insert(lines, "")

  -- Build the info line with sample text that will be highlighted
  local orig_text = "Original"
  local curr_text = "Current"
  local info_line = string.format(
    "%s%s   %s   %s %s bold %s italic",
    pad, orig_text, curr_text, mode, bold_indicator, italic_indicator
  )
  table.insert(lines, info_line)

  -- Calculate highlight positions (1-indexed to 0-indexed for nvim_buf_add_highlight)
  local orig_start = PADDING
  local orig_end = PADDING + #orig_text
  local curr_start = PADDING + #orig_text + 3 -- "   " separator
  local curr_end = curr_start + #curr_text

  table.insert(highlights, {
    line = #lines - 1,
    col_start = orig_start,
    col_end = orig_end,
    hl_group = orig_hl_name,
  })

  table.insert(highlights, {
    line = #lines - 1,
    col_start = curr_start,
    col_end = curr_end,
    hl_group = curr_hl_name,
  })

  -- Help hint line with step size indicator
  table.insert(lines, "")
  local step_label = get_step_label()
  table.insert(lines, pad .. "Step: " .. step_label .. "  (-/+ adjust)     ? = Controls")

  return lines, highlights
end

---Full render of the picker
local function render()
  if not state or not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local lines = {}
  local all_highlights = {}

  -- Header
  local pad = string.rep(" ", PADDING)
  local title = state.options.title or "Pick Color"
  table.insert(lines, "")
  table.insert(lines, pad .. title)
  table.insert(lines, "")

  -- Track line offset for highlights
  local line_offset = #lines

  -- Grid
  local grid_lines, grid_highlights = render_grid()
  for _, line in ipairs(grid_lines) do
    table.insert(lines, line)
  end
  for _, hl in ipairs(grid_highlights) do
    hl.line = hl.line + line_offset
    table.insert(all_highlights, hl)
  end

  line_offset = #lines
  table.insert(lines, "") -- Spacing before preview

  -- Preview
  line_offset = #lines
  local preview_lines, preview_highlights = render_preview()
  for _, line in ipairs(preview_lines) do
    table.insert(lines, line)
  end
  for _, hl in ipairs(preview_highlights) do
    hl.line = hl.line + line_offset
    table.insert(all_highlights, hl)
  end

  -- Footer
  line_offset = #lines
  local footer_lines, footer_highlights = render_footer()
  for _, line in ipairs(footer_lines) do
    table.insert(lines, line)
  end
  for _, hl in ipairs(footer_highlights) do
    hl.line = hl.line + line_offset
    table.insert(all_highlights, hl)
  end

  -- Update buffer
  vim.api.nvim_buf_set_option(state.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.buf, "modifiable", false)

  -- Apply highlights
  vim.api.nvim_buf_clear_namespace(state.buf, state.ns, 0, -1)
  for _, hl in ipairs(all_highlights) do
    vim.api.nvim_buf_add_highlight(
      state.buf,
      state.ns,
      hl.hl_group,
      hl.line,
      hl.col_start,
      hl.col_end
    )
  end

  -- Title highlight
  vim.api.nvim_buf_add_highlight(state.buf, state.ns, "SsnsFloatTitle", 1, 0, -1)

  -- Trigger on_change callback
  if state.options.on_change then
    state.options.on_change(vim.deepcopy(state.current))
  end
end

---Increase step size
local function increase_step_size()
  if not state then return end
  if state.step_index < #STEP_SIZES then
    state.step_index = state.step_index + 1
    render()
  end
end

---Decrease step size
local function decrease_step_size()
  if not state then return end
  if state.step_index > 1 then
    state.step_index = state.step_index - 1
    render()
  end
end

-- ============================================================================
-- Navigation
-- ============================================================================

---Shift hue
---@param delta number Positive = right (increase hue), negative = left
local function shift_hue(delta)
  if not state then return end
  local current = get_active_color()
  local step = delta * BASE_STEP_HUE * get_step_multiplier()
  local new_color = ColorUtils.adjust_hue(current, step)

  -- Update saved_hsl hue so grid reflects changes even at lightness extremes
  if state.saved_hsl then
    local h, _, _ = ColorUtils.hex_to_hsl(new_color)
    state.saved_hsl.h = h
  end

  set_active_color(new_color)
  render()
end

---Shift lightness with bounce and color band memory
---Uses virtual position for continuous scrolling: k always "goes up"
---@param delta number Positive = up (increase lightness), negative = down
local function shift_lightness(delta)
  if not state then return end
  local current = get_active_color()
  local h, s, l = ColorUtils.hex_to_hsl(current)

  -- Initialize virtual position from actual lightness if not set
  if not state.lightness_virtual then
    state.lightness_virtual = l
  end

  -- Save the color band (hue + saturation) when in the colorful range
  -- At extremes (near black or white), hue/sat become meaningless
  if l > 2 and l < 98 and s > 5 then
    state.saved_hsl = { h = h, s = s }
  end

  -- Calculate step and add to virtual position (no direction multiplier!)
  -- k always increases virtual, j always decreases - feels consistent to user
  local step = delta * BASE_STEP_LIGHTNESS * get_step_multiplier()
  state.lightness_virtual = state.lightness_virtual + step

  -- Map virtual position to actual 0-100 with bounce
  local new_l = virtual_to_actual(state.lightness_virtual)

  -- Restore saved hue/saturation when in colorful range
  local new_h, new_s = h, s
  if state.saved_hsl and new_l > 2 and new_l < 98 then
    new_h = state.saved_hsl.h
    new_s = state.saved_hsl.s
  end

  local new_color = ColorUtils.hsl_to_hex(new_h, new_s, new_l)
  set_active_color(new_color)
  render()
end

---Shift saturation with bounce
---Uses virtual position for continuous scrolling: K always "goes up"
---@param delta number Positive = increase, negative = decrease
local function shift_saturation(delta)
  if not state then return end
  local current = get_active_color()
  local h, s, l = ColorUtils.hex_to_hsl(current)

  -- Initialize virtual position from actual saturation if not set
  if not state.saturation_virtual then
    state.saturation_virtual = s
  end

  -- Calculate step and add to virtual position (no direction multiplier!)
  -- K always increases virtual, J always decreases - feels consistent to user
  local step = delta * BASE_STEP_SATURATION * get_step_multiplier()
  state.saturation_virtual = state.saturation_virtual + step

  -- Map virtual position to actual 0-100 with bounce
  local new_s = virtual_to_actual(state.saturation_virtual)

  -- Update saved_hsl saturation so grid reflects changes even at lightness extremes
  if state.saved_hsl then
    state.saved_hsl.s = new_s
  end

  local new_color = ColorUtils.hsl_to_hex(h, new_s, l)
  set_active_color(new_color)
  render()
end

---Toggle bold
local function toggle_bold()
  if not state then return end
  state.current.bold = not state.current.bold
  render()
end

---Toggle italic
local function toggle_italic()
  if not state then return end
  state.current.italic = not state.current.italic
  render()
end

---Toggle editing fg/bg
local function toggle_bg_mode()
  if not state then return end
  state.editing_bg = not state.editing_bg
  render()
end

---Reset to original color
local function reset_color()
  if not state then return end
  state.current = vim.deepcopy(state.original)
  state.editing_bg = false
  render()
end

---Clear background color
local function clear_bg()
  if not state then return end
  state.current.bg = nil
  render()
end

---Enter hex input mode
local function enter_hex_input()
  if not state then return end

  local current = get_active_color()

  vim.ui.input({
    prompt = "Enter hex color: ",
    default = current,
  }, function(input)
    if input and ColorUtils.is_valid_hex(input) then
      set_active_color(input)
      render()
    elseif input then
      vim.notify("Invalid hex color: " .. input, vim.log.levels.WARN)
    end
  end)
end

---Apply and close
local function apply()
  if not state then return end

  local result = vim.deepcopy(state.current)

  if state.options.on_select then
    state.options.on_select(result)
  end

  ColorPicker.close()
end

---Cancel and close
local function cancel()
  if not state then return end

  if state.options.on_cancel then
    state.options.on_cancel()
  end

  ColorPicker.close()
end

-- ============================================================================
-- Help Popup
-- ============================================================================

---Close the help popup
local function close_help()
  if not state then return end

  if state.help_win and vim.api.nvim_win_is_valid(state.help_win) then
    vim.api.nvim_win_close(state.help_win, true)
  end

  if state.help_buf and vim.api.nvim_buf_is_valid(state.help_buf) then
    vim.api.nvim_buf_delete(state.help_buf, { force = true })
  end

  state.help_win = nil
  state.help_buf = nil
end

---Show the help popup
local function show_help()
  if not state or not state.win then return end

  -- Close existing help if open
  close_help()

  local help_lines = {
    "",
    "  Color Picker Controls",
    "  ─────────────────────",
    "",
    "  Navigation",
    "  ──────────",
    "  h / l       Move hue (left/right)",
    "  j / k       Adjust lightness (down/up)",
    "  J / K       Adjust saturation (less/more)",
    "",
    "  Use counts for bigger steps: 10h, 50k",
    "",
    "  Step Size",
    "  ─────────",
    "  - / +       Decrease/increase step size",
    "              (¼× ½× 1× 2× 4× 8×)",
    "",
    "  Styles",
    "  ──────",
    "  b           Toggle bold",
    "  i           Toggle italic",
    "  B           Switch to edit background",
    "  x           Clear background color",
    "",
    "  Actions",
    "  ───────",
    "  #           Enter hex color manually",
    "  r           Reset to original",
    "  Enter       Apply and close",
    "  q / Esc     Cancel and close",
    "",
    "  Press any key to close this help",
    "",
  }

  local help_width = 42
  local help_height = #help_lines

  -- Create help buffer
  local help_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(help_buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(help_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, help_lines)
  vim.api.nvim_buf_set_option(help_buf, "modifiable", false)

  -- Position centered over main picker
  local win_config = vim.api.nvim_win_get_config(state.win)
  local help_row = win_config.row[false] + math.floor((win_config.height - help_height) / 2)
  local help_col = win_config.col[false] + math.floor((win_config.width - help_width) / 2)

  local help_win = vim.api.nvim_open_win(help_buf, true, {
    relative = "editor",
    width = help_width,
    height = help_height,
    row = help_row,
    col = help_col,
    style = "minimal",
    border = "rounded",
    title = " Help ",
    title_pos = "center",
    zindex = 150,
  })

  state.help_buf = help_buf
  state.help_win = help_win

  -- Highlight title
  local ns = vim.api.nvim_create_namespace("ssns_color_picker_help")
  vim.api.nvim_buf_add_highlight(help_buf, ns, "SsnsFloatTitle", 1, 0, -1)

  -- Close on any key
  local function close_on_key()
    close_help()
  end

  -- Map common keys to close
  local close_keys = { "<Esc>", "q", "<CR>", "?", "<Space>" }
  for _, key in ipairs(close_keys) do
    vim.keymap.set("n", key, close_on_key, { buffer = help_buf, nowait = true, silent = true })
  end

  -- Also close on any other key using a catch-all
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = help_buf,
    once = true,
    callback = close_on_key,
  })
end

-- ============================================================================
-- Keymaps
-- ============================================================================

---Setup keymaps with vim count support
local function setup_keymaps()
  if not state or not state.buf then return end

  local buf = state.buf

  local function map(key, fn)
    vim.keymap.set("n", key, fn, { buffer = buf, nowait = true, silent = true })
  end

  -- Navigation with count support
  map("h", function()
    local count = vim.v.count1
    shift_hue(-count)
  end)

  map("l", function()
    local count = vim.v.count1
    shift_hue(count)
  end)

  map("k", function()
    local count = vim.v.count1
    shift_lightness(count)
  end)

  map("j", function()
    local count = vim.v.count1
    shift_lightness(-count)
  end)

  -- Saturation with Shift + j/k
  map("K", function()
    local count = vim.v.count1
    shift_saturation(count)
  end)

  map("J", function()
    local count = vim.v.count1
    shift_saturation(-count)
  end)

  -- Toggles
  map("b", toggle_bold)
  map("i", toggle_italic)
  map("B", toggle_bg_mode)
  map("x", clear_bg)

  -- Actions
  map("r", reset_color)
  map("#", enter_hex_input)
  map("<CR>", apply)
  map("q", cancel)
  map("<Esc>", cancel)

  -- Help
  map("?", show_help)

  -- Step size adjustment
  map("-", decrease_step_size)
  map("+", increase_step_size)
  map("=", increase_step_size)  -- = is + without shift
end

-- ============================================================================
-- Window Management
-- ============================================================================

---Handle window resize
local function on_resize()
  if not state or not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end

  local win_width = vim.api.nvim_win_get_width(state.win)
  local win_height = vim.api.nvim_win_get_height(state.win)

  local new_width, new_height = calculate_grid_size(win_width, win_height)

  if new_width ~= state.grid_width or new_height ~= state.grid_height then
    state.grid_width = new_width
    state.grid_height = new_height
    render()
  end
end

---Close the color picker
function ColorPicker.close()
  if not state then return end

  -- Save references before closing (WinClosed autocmd sets state = nil)
  local help_win = state.help_win
  local help_buf = state.help_buf
  local grid_height = state.grid_height or 20
  local grid_width = state.grid_width or 60
  local win = state.win
  local buf = state.buf

  -- Clear state first to prevent re-entrancy issues
  state = nil

  -- Close help popup if open
  if help_win and vim.api.nvim_win_is_valid(help_win) then
    vim.api.nvim_win_close(help_win, true)
  end
  if help_buf and vim.api.nvim_buf_is_valid(help_buf) then
    vim.api.nvim_buf_delete(help_buf, { force = true })
  end

  -- Clean up highlight groups
  for row = 1, grid_height do
    for col = 1, grid_width do
      pcall(vim.api.nvim_set_hl, 0, get_cell_hl_group(row, col), {})
    end
  end
  pcall(vim.api.nvim_set_hl, 0, "ColorPickerPreview", {})
  pcall(vim.api.nvim_set_hl, 0, "ColorPickerOriginalPreview", {})
  pcall(vim.api.nvim_set_hl, 0, "ColorPickerCurrentPreview", {})

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end

  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

---Show the color picker
---@param options ColorPickerOptions
function ColorPicker.show(options)
  -- Close existing picker
  ColorPicker.close()

  -- Validate options
  if not options or not options.initial then
    vim.notify("ColorPicker: initial color required", vim.log.levels.ERROR)
    return
  end

  -- Normalize initial color
  local initial = vim.deepcopy(options.initial)
  if initial.fg then
    initial.fg = ColorUtils.normalize_hex(initial.fg)
  else
    initial.fg = "#808080"
  end
  if initial.bg then
    initial.bg = ColorUtils.normalize_hex(initial.bg)
  end

  -- Calculate window size
  local ui = vim.api.nvim_list_uis()[1]
  local max_width = math.floor(ui.width * 0.8)
  local max_height = math.floor(ui.height * 0.7)

  -- Ensure reasonable minimums
  max_width = math.max(50, max_width)
  max_height = math.max(15, max_height)

  local grid_width, grid_height = calculate_grid_size(max_width, max_height)

  -- Calculate actual window size needed
  local win_width = grid_width + PADDING * 2
  local win_height = HEADER_HEIGHT + grid_height + 1 + PREVIEW_HEIGHT + 2 + FOOTER_HEIGHT

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "filetype", "ssns-colorpicker")

  -- Create window
  local row = math.floor((ui.height - win_height) / 2)
  local col = math.floor((ui.width - win_width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Color Picker ",
    title_pos = "center",
    zindex = 100,
  })

  -- Window options
  vim.api.nvim_win_set_option(win, "cursorline", false)
  vim.api.nvim_win_set_option(win, "wrap", false)
  vim.api.nvim_win_set_option(win, "number", false)
  vim.api.nvim_win_set_option(win, "relativenumber", false)
  vim.api.nvim_win_set_option(win, "signcolumn", "no")

  -- Initialize state
  -- Pre-compute initial HSL for color band memory
  local initial_hsl = nil
  if initial.fg then
    local h, s, _ = ColorUtils.hex_to_hsl(initial.fg)
    initial_hsl = { h = h, s = s }
  end

  state = {
    current = vim.deepcopy(initial),
    original = vim.deepcopy(initial),
    editing_bg = false,
    grid_width = grid_width,
    grid_height = grid_height,
    win = win,
    buf = buf,
    ns = vim.api.nvim_create_namespace("ssns_color_picker"),
    options = options,
    saved_hsl = initial_hsl,
    help_win = nil,
    help_buf = nil,
    step_index = DEFAULT_STEP_INDEX,
    lightness_virtual = nil,  -- Initialized on first navigation
    saturation_virtual = nil, -- Initialized on first navigation
  }

  -- Setup keymaps
  setup_keymaps()

  -- Setup resize handler
  local augroup = vim.api.nvim_create_augroup("SSNSColorPicker", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = augroup,
    callback = on_resize,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    pattern = tostring(win),
    callback = function()
      vim.api.nvim_del_augroup_by_id(augroup)
      state = nil
    end,
  })

  -- Initial render
  render()
end

---Check if picker is open
---@return boolean
function ColorPicker.is_open()
  return state ~= nil
end

---Get current state (for external access if needed)
---@return ColorPickerState?
function ColorPicker.get_state()
  return state
end

return ColorPicker
