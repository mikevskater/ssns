---@class ColorPicker
---Interactive color picker with HSL grid navigation
local ColorPicker = {}

local ColorUtils = require('ssns.ui.components.color_utils')
local UiFloat = require('ssns.ui.core.float')
local ContentBuilder = require('ssns.ui.core.content_builder')
local KeymapManager = require('ssns.keymap_manager')
local Config = require('ssns.config')

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
---@field step_index number Index into STEP_SIZES array
---@field lightness_virtual number? Virtual lightness position (can exceed 0-100 for bounce)
---@field saturation_virtual number? Virtual saturation position (can exceed 0-100 for bounce)
---@field _float FloatWindow? Reference to UiFloat window instance
---@field _render_pending boolean? Whether a render is scheduled
---@field _render_timer number? Timer handle for debounced render

-- ============================================================================
-- Constants
-- ============================================================================

local PREVIEW_HEIGHT = 2    -- Rows for color preview
local PREVIEW_BORDERS = 2   -- Top and bottom border lines around preview
local FOOTER_HEIGHT = 4     -- Blank + info line + blank + help hint
local HEADER_HEIGHT = 3     -- Blank + title + blank
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
  -- Account for: header, preview with borders, footer, and spacing line between grid and preview
  local available_height = win_height - HEADER_HEIGHT - (PREVIEW_HEIGHT + PREVIEW_BORDERS) - FOOTER_HEIGHT - 1

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

-- ============================================================================
-- ContentBuilder Render Functions
-- ============================================================================

---Render header using ContentBuilder
---@return ContentBuilder cb The content builder with header content
local function render_header_cb()
  local cb = ContentBuilder.new()

  cb:blank()
  cb:styled("  " .. (state and state.options.title or "Pick Color"), "header")
  cb:blank()

  return cb
end

---Render footer using ContentBuilder (with custom color swatch highlights applied separately)
---@return ContentBuilder cb The content builder with footer content
---@return table swatch_info Info needed for applying color swatch highlights
local function render_footer_cb()
  local cb = ContentBuilder.new()

  if not state then return cb, {} end

  -- Mode and style indicators
  local mode = state.editing_bg and "[bg]" or "[fg]"
  local bold_indicator = state.current.bold and "[B]" or "[ ]"
  local italic_indicator = state.current.italic and "[I]" or "[ ]"

  cb:blank()

  -- Build info line using spans for styling
  -- Note: "Original" and "Current" text will get color swatch highlights applied separately
  cb:spans({
    { text = "  Original", style = "label" },
    { text = "   ", style = "muted" },
    { text = "Current", style = "label" },
    { text = "   " .. mode .. " ", style = "muted" },
    { text = bold_indicator .. " bold ", style = state.current.bold and "emphasis" or "muted" },
    { text = italic_indicator .. " italic", style = state.current.italic and "emphasis" or "muted" },
  })

  cb:blank()

  -- Step size and help hint
  local step_label = get_step_label()
  cb:spans({
    { text = "  Step: ", style = "label" },
    { text = step_label, style = "value" },
    { text = "  (-/+ adjust)", style = "muted" },
    { text = "     ", style = "muted" },
    { text = "? = Controls", style = "key" },
  })

  -- Return info for applying color swatch highlights
  -- Line 1 (0-indexed after blank) has "Original" at col 2-10 and "Current" at col 13-20
  local swatch_info = {
    original = { line_offset = 1, col_start = 2, col_end = 10 },  -- "Original"
    current = { line_offset = 1, col_start = 13, col_end = 20 },  -- "Current"
  }

  return cb, swatch_info
end

---Apply color swatch highlights to "Original" and "Current" text
---@param base_line number Line offset in buffer where footer starts
---@param swatch_info table Info from render_footer_cb
local function apply_swatch_highlights(base_line, swatch_info)
  if not state then return end

  -- Create highlight groups for Original and Current preview text
  local orig_hl_name = "ColorPickerOriginalPreview"
  local curr_hl_name = "ColorPickerCurrentPreview"

  -- Get original color
  local orig_color = state.editing_bg
    and (state.original.bg or "none")
    or (state.original.fg or "none")

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

  -- Apply highlights
  local orig_info = swatch_info.original
  local curr_info = swatch_info.current

  vim.api.nvim_buf_add_highlight(
    state.buf,
    state.ns,
    orig_hl_name,
    base_line + orig_info.line_offset,
    orig_info.col_start,
    orig_info.col_end
  )

  vim.api.nvim_buf_add_highlight(
    state.buf,
    state.ns,
    curr_hl_name,
    base_line + curr_info.line_offset,
    curr_info.col_start,
    curr_info.col_end
  )
end

-- Forward declaration for schedule_render (defined after render)
local schedule_render

---Full render of the picker (hybrid approach: ContentBuilder for header/footer, custom for grid/preview)
---This function does the actual synchronous render work
local function render()
  if not state or not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  -- Clear pending flag since we're now rendering
  state._render_pending = false

  local all_lines = {}
  local all_highlights = {}
  local line_offset = 0

  -- 1. Header via ContentBuilder
  local header_cb = render_header_cb()
  local header_lines = header_cb:build_lines()
  local header_highlights = header_cb:build_highlights()

  for _, line in ipairs(header_lines) do
    table.insert(all_lines, line)
  end
  for _, hl in ipairs(header_highlights) do
    table.insert(all_highlights, {
      line = hl.line + line_offset,
      col_start = hl.col_start,
      col_end = hl.col_end,
      hl_group = hl.hl_group,
    })
  end
  line_offset = #all_lines

  -- 2. Grid (custom rendering - per-cell highlights)
  local grid_lines, grid_highlights = render_grid()
  for _, line in ipairs(grid_lines) do
    table.insert(all_lines, line)
  end
  for _, hl in ipairs(grid_highlights) do
    table.insert(all_highlights, {
      line = hl.line + line_offset,
      col_start = hl.col_start,
      col_end = hl.col_end,
      hl_group = hl.hl_group,
    })
  end
  line_offset = #all_lines

  -- Spacing before preview
  table.insert(all_lines, "")
  line_offset = #all_lines

  -- 3. Preview (custom rendering - dynamic background color)
  local preview_lines, preview_highlights = render_preview()
  for _, line in ipairs(preview_lines) do
    table.insert(all_lines, line)
  end
  for _, hl in ipairs(preview_highlights) do
    table.insert(all_highlights, {
      line = hl.line + line_offset,
      col_start = hl.col_start,
      col_end = hl.col_end,
      hl_group = hl.hl_group,
    })
  end

  -- Track footer start line for swatch highlights
  local footer_start_line = #all_lines

  -- 4. Footer via ContentBuilder
  local footer_cb, swatch_info = render_footer_cb()
  local footer_lines = footer_cb:build_lines()
  local footer_highlights = footer_cb:build_highlights()

  for _, line in ipairs(footer_lines) do
    table.insert(all_lines, line)
  end
  for _, hl in ipairs(footer_highlights) do
    table.insert(all_highlights, {
      line = hl.line + footer_start_line,
      col_start = hl.col_start,
      col_end = hl.col_end,
      hl_group = hl.hl_group,
    })
  end

  -- Update buffer
  vim.api.nvim_buf_set_option(state.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, all_lines)
  vim.api.nvim_buf_set_option(state.buf, "modifiable", false)

  -- Apply all highlights
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

  -- Apply custom color swatch highlights (Original/Current text with actual colors)
  apply_swatch_highlights(footer_start_line, swatch_info)

  -- Trigger on_change callback
  if state.options.on_change then
    state.options.on_change(vim.deepcopy(state.current))
  end
end

---Schedule a render for the next event loop iteration
---Coalesces multiple calls - if a render is already pending, skip scheduling another
---Uses vim.schedule() with no delay to ensure the X marker stays in center
schedule_render = function()
  if not state or not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  -- If render already pending, skip - coalesce multiple rapid calls
  if state._render_pending then
    return
  end

  -- Mark as pending and schedule for next event loop
  state._render_pending = true
  vim.schedule(function()
    -- Double-check state is still valid when we actually run
    if state and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
      render()
    end
  end)
end

---Increase step size
local function increase_step_size()
  if not state then return end
  if state.step_index < #STEP_SIZES then
    state.step_index = state.step_index + 1
    schedule_render()
  end
end

---Decrease step size
local function decrease_step_size()
  if not state then return end
  if state.step_index > 1 then
    state.step_index = state.step_index - 1
    schedule_render()
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
  schedule_render()
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
  schedule_render()
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
  schedule_render()
end

---Toggle bold
local function toggle_bold()
  if not state then return end
  state.current.bold = not state.current.bold
  schedule_render()
end

---Toggle italic
local function toggle_italic()
  if not state then return end
  state.current.italic = not state.current.italic
  schedule_render()
end

---Toggle editing fg/bg
local function toggle_bg_mode()
  if not state then return end
  state.editing_bg = not state.editing_bg
  schedule_render()
end

---Reset to original color
local function reset_color()
  if not state then return end
  state.current = vim.deepcopy(state.original)
  state.editing_bg = false
  schedule_render()
end

---Clear background color
local function clear_bg()
  if not state then return end
  state.current.bg = nil
  schedule_render()
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
      schedule_render()
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

  -- Revert preview to original before closing
  -- This ensures live preview reverts before picker closes
  if state.options.on_change then
    state.options.on_change(vim.deepcopy(state.original))
  end

  if state.options.on_cancel then
    state.options.on_cancel()
  end

  ColorPicker.close()
end

-- ============================================================================
-- Controls Definition (for UiFloat help popup)
-- ============================================================================

---Get controls definition for the color picker
---@return ControlsDefinition[]
local function get_controls_definition()
  return {
    {
      header = "Navigation",
      keys = {
        { key = "h / l", desc = "Move hue (left/right)" },
        { key = "j / k", desc = "Adjust lightness (down/up)" },
        { key = "J / K", desc = "Adjust saturation (less/more)" },
        { key = "[count]", desc = "Use counts: 10h, 50k" },
      }
    },
    {
      header = "Step Size",
      keys = {
        { key = "- / +", desc = "Decrease/increase multiplier" },
      }
    },
    {
      header = "Styles",
      keys = {
        { key = "b", desc = "Toggle bold" },
        { key = "i", desc = "Toggle italic" },
        { key = "B", desc = "Switch to edit background" },
        { key = "x", desc = "Clear background color" },
      }
    },
    {
      header = "Actions",
      keys = {
        { key = "#", desc = "Enter hex color manually" },
        { key = "r", desc = "Reset to original" },
        { key = "Enter", desc = "Apply and close" },
        { key = "q / Esc", desc = "Cancel and close" },
      }
    },
  }
end

---Show the help popup using UiFloat's controls system
local function show_help()
  if not state or not state._float then return end
  state._float:show_controls(get_controls_definition())
end

-- ============================================================================
-- Keymaps
-- ============================================================================

---Setup keymaps using KeymapManager and config (supports vim count for navigation)
local function setup_keymaps()
  if not state or not state.buf then return end

  local buf = state.buf
  local cfg = Config.get().keymaps.colorpicker or {}

  -- Initialize KeymapManager for this buffer
  KeymapManager.init_buffer(buf)

  -- Helper to get key(s) from config with fallback
  local function get_key(name, default)
    return cfg[name] or default
  end

  -- Helper to add keymap(s) - handles both single key and array of keys
  local function add_maps(key_or_keys, fn, keymaps_table)
    local keys = type(key_or_keys) == "table" and key_or_keys or { key_or_keys }
    for _, k in ipairs(keys) do
      table.insert(keymaps_table, {
        mode = "n",
        lhs = k,
        rhs = fn,
        opts = { nowait = true, silent = true }
      })
    end
  end

  local keymaps = {}

  -- Navigation with count support
  add_maps(get_key("nav_left", "h"), function()
    local count = vim.v.count1
    shift_hue(-count)
  end, keymaps)

  add_maps(get_key("nav_right", "l"), function()
    local count = vim.v.count1
    shift_hue(count)
  end, keymaps)

  add_maps(get_key("nav_up", "k"), function()
    local count = vim.v.count1
    shift_lightness(count)
  end, keymaps)

  add_maps(get_key("nav_down", "j"), function()
    local count = vim.v.count1
    shift_lightness(-count)
  end, keymaps)

  -- Saturation
  add_maps(get_key("sat_up", "K"), function()
    local count = vim.v.count1
    shift_saturation(count)
  end, keymaps)

  add_maps(get_key("sat_down", "J"), function()
    local count = vim.v.count1
    shift_saturation(-count)
  end, keymaps)

  -- Toggles
  add_maps(get_key("toggle_bold", "b"), toggle_bold, keymaps)
  add_maps(get_key("toggle_italic", "i"), toggle_italic, keymaps)
  add_maps(get_key("toggle_bg", "B"), toggle_bg_mode, keymaps)
  add_maps(get_key("clear_bg", "x"), clear_bg, keymaps)

  -- Actions
  add_maps(get_key("reset", "r"), reset_color, keymaps)
  add_maps(get_key("hex_input", "#"), enter_hex_input, keymaps)
  add_maps(get_key("apply", "<CR>"), apply, keymaps)
  add_maps(get_key("cancel", { "q", "<Esc>" }), cancel, keymaps)

  -- Help
  add_maps(get_key("help", "?"), show_help, keymaps)

  -- Step size adjustment
  add_maps(get_key("step_down", "-"), decrease_step_size, keymaps)
  add_maps(get_key("step_up", { "+", "=" }), increase_step_size, keymaps)

  -- Apply all keymaps using KeymapManager (saves conflicts, auto-restores on close)
  KeymapManager.set_multiple(buf, keymaps, true)
  KeymapManager.setup_auto_restore(buf)
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
    schedule_render()
  end
end

---Close the color picker
function ColorPicker.close()
  if not state then return end

  -- Save references before closing (WinClosed autocmd sets state = nil)
  local grid_height = state.grid_height or 20
  local grid_width = state.grid_width or 60
  local float = state._float

  -- Clear state first to prevent re-entrancy issues
  state = nil

  -- Clean up highlight groups
  for row = 1, grid_height do
    for col = 1, grid_width do
      pcall(vim.api.nvim_set_hl, 0, get_cell_hl_group(row, col), {})
    end
  end
  pcall(vim.api.nvim_set_hl, 0, "ColorPickerPreview", {})
  pcall(vim.api.nvim_set_hl, 0, "ColorPickerOriginalPreview", {})
  pcall(vim.api.nvim_set_hl, 0, "ColorPickerCurrentPreview", {})

  -- Close the floating window using UiFloat
  if float and float:is_valid() then
    float:close()
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
  -- Height: header + grid + spacing + preview with borders + footer
  local win_height = HEADER_HEIGHT + grid_height + 1 + (PREVIEW_HEIGHT + PREVIEW_BORDERS) + FOOTER_HEIGHT

  -- Create floating window using UiFloat
  local float = UiFloat.create({
    title = "Color Picker",
    width = win_width,
    height = win_height,
    centered = true,
    zindex = UiFloat.ZINDEX.OVERLAY,  -- 100 - above other floats like theme editor
    default_keymaps = false,  -- We manage keymaps ourselves
    scrollbar = false,  -- Grid doesn't scroll
    modifiable = true,  -- We update content via render()
    readonly = false,
    cursorline = false,
    wrap = false,
    filetype = "ssns-colorpicker",
    controls = get_controls_definition(),  -- For ? popup
    footer = "? = Controls",
  })

  if not float or not float:is_valid() then
    vim.notify("ColorPicker: Failed to create window", vim.log.levels.ERROR)
    return
  end

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
    win = float.winid,
    buf = float.bufnr,
    ns = vim.api.nvim_create_namespace("ssns_color_picker"),
    options = options,
    saved_hsl = initial_hsl,
    step_index = DEFAULT_STEP_INDEX,
    lightness_virtual = nil,  -- Initialized on first navigation
    saturation_virtual = nil, -- Initialized on first navigation
    _float = float,  -- Keep reference to FloatWindow for controls popup
  }

  -- Setup keymaps
  setup_keymaps()

  -- Setup cleanup handler for when window closes
  -- UiFloat handles VimResized internally, we just need cleanup
  local augroup = vim.api.nvim_create_augroup("SSNSColorPicker", { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    pattern = tostring(float.winid),
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
