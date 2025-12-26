---@class ColorPicker
---Interactive color picker with HSL grid navigation
local ColorPicker = {}

local ColorUtils = require('ssns.ui.components.color_utils')
local UiFloat = require('ssns.ui.core.float')
local MultiPanel = require('ssns.ui.core.float.multipanel')
local ContentBuilder = require('ssns.ui.core.content_builder')
local InputManager = require('ssns.ui.core.input_manager')
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
---@field forced_mode "hsl"|"rgb"|"cmyk"|"hsv"? Force specific color mode (locks mode switching)
---@field alpha_enabled boolean? Allow alpha editing (default: false)
---@field initial_alpha number? Initial alpha value 0-100 (default: 100)

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
---@field color_mode "hsl"|"rgb"|"cmyk"|"hsv" Current color mode for info panel
---@field value_format "standard"|"decimal" Value display format
---@field alpha number Alpha value 0-100
---@field alpha_enabled boolean Whether alpha editing is available
---@field focused_panel "grid"|"info" Currently focused panel
---@field _multipanel table? MultiPanelWindow instance (for multipanel mode)
---@field _info_panel_cb table? ContentBuilder for info panel (stores inputs)
---@field _info_input_manager table? InputManager for info panel

-- ============================================================================
-- Constants
-- ============================================================================

local PREVIEW_HEIGHT = 2    -- Rows for color preview
local PREVIEW_BORDERS = 2   -- Top and bottom border lines around preview
local FOOTER_HEIGHT = 6     -- Blank + info line + blank + mode/step line + blank + help hint
local HEADER_HEIGHT = 3     -- Blank + title + blank
local PADDING = 2           -- Left/right padding

local BASE_STEP_HUE = 3          -- Base hue degrees per grid cell
local BASE_STEP_LIGHTNESS = 2    -- Base lightness percent per grid row
local BASE_STEP_SATURATION = 2   -- Base saturation percent per J/K press

-- Step size multipliers (index 3 is default 1x)
local STEP_SIZES = { 0.25, 0.5, 1, 2, 4, 8 }
local STEP_LABELS = { "¼×", "½×", "1×", "2×", "4×", "8×" }
local DEFAULT_STEP_INDEX = 3  -- 1x multiplier

-- Alpha visualization characters (for preview section)
-- Uses block shades for high opacity, braille patterns for low opacity
-- Braille provides smooth density transitions: ⣿(8)→⣶(6)→⡆(4)→⠆(3)→⠂(2)→⠁(1)→⠀(0)
local ALPHA_CHARS = {
  { min = 100, max = 100, char = "█" },  -- 100% full block
  { min = 85,  max = 99,  char = "▓" },  -- 85-99% dark shade
  { min = 70,  max = 84,  char = "▒" },  -- 70-84% medium shade
  { min = 55,  max = 69,  char = "░" },  -- 55-69% light shade
  { min = 42,  max = 54,  char = "⣿" },  -- 42-54% braille 8 dots
  { min = 30,  max = 41,  char = "⣶" },  -- 30-41% braille 6 dots
  { min = 20,  max = 29,  char = "⠭" },  -- 20-29% braille 4 dots
  { min = 12,  max = 19,  char = "⠪" },  -- 12-19% braille 3 dots
  { min = 6,   max = 11,  char = "⠊" },  -- 6-11% braille 2 dots
  { min = 2,   max = 5,   char = "⠁" },  -- 2-5% braille 1 dot
  { min = 0,   max = 1,   char = "⠀" },  -- 0-1% braille blank
}

-- Color modes available
local COLOR_MODES = { "hsl", "rgb", "cmyk", "hsv" }

-- Minimum width for side-by-side layout (below this, use stacked)
local MIN_SIDE_BY_SIDE_WIDTH = 80

-- Info panel minimum dimensions
local INFO_PANEL_MIN_WIDTH = 22
local INFO_PANEL_MIN_HEIGHT = 12

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

---Get the alpha visualization character for a given alpha value
---@param alpha number Alpha value 0-100
---@return string char The character representing the alpha level
local function get_alpha_char(alpha)
  for _, def in ipairs(ALPHA_CHARS) do
    if alpha >= def.min and alpha <= def.max then
      return def.char
    end
  end
  return "█"  -- Fallback to fully opaque
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
---Uses background color with space character for simpler rendering
---@param grid string[][] The color grid
local function create_grid_highlights(grid)
  if not state then return end

  local center_row = math.ceil(#grid / 2)
  local center_col = math.ceil(#grid[1] / 2)

  for row_idx, row in ipairs(grid) do
    for col_idx, color in ipairs(row) do
      local hl_name = get_cell_hl_group(row_idx, col_idx)
      local hl_def

      -- Center cell gets contrasting X marker
      if row_idx == center_row and col_idx == center_col then
        hl_def = {
          fg = ColorUtils.get_contrast_color(color),
          bg = color,
          bold = true,
        }
      else
        -- Non-center cells use background color with space character
        hl_def = { bg = color }
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
      local char = " "  -- Space with background color
      -- Center cell gets X marker
      if row_idx == center_row and col_idx == center_col then
        char = "X"
      end
      table.insert(line_chars, char)

      -- Store highlight info (all chars are 1 byte)
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

---Render the preview section with alpha visualization
---Uses different characters to represent opacity levels
---@return string[] lines
---@return table[] highlights
local function render_preview()
  if not state then return {}, {} end

  local lines = {}
  local highlights = {}
  local pad = string.rep(" ", PADDING)

  -- Get the preview color and alpha
  local preview_color = get_active_color()
  local alpha = state.alpha or 100

  -- Get the alpha visualization character
  local alpha_char = get_alpha_char(alpha)
  local alpha_char_len = #alpha_char  -- Byte length (multi-byte for unicode chars)

  -- Create preview highlight using foreground color (for alpha visualization)
  vim.api.nvim_set_hl(0, "ColorPickerPreview", { fg = preview_color })

  -- Preview border (─ is 3 bytes)
  local border_char = "─"
  local preview_width = state.grid_width
  table.insert(lines, pad .. string.rep(border_char, preview_width))

  -- Preview rows (filled with alpha character using foreground color)
  -- Calculate byte length of the preview content
  local preview_byte_len = preview_width * alpha_char_len

  for i = 1, PREVIEW_HEIGHT do
    local preview_line = pad .. string.rep(alpha_char, preview_width)
    table.insert(lines, preview_line)
    table.insert(highlights, {
      line = #lines - 1,
      col_start = PADDING,
      col_end = PADDING + preview_byte_len,
      hl_group = "ColorPickerPreview",
    })
  end

  table.insert(lines, pad .. string.rep(border_char, preview_width))

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
  local fg_bg_mode = state.editing_bg and "[bg]" or "[fg]"
  local bold_indicator = state.current.bold and "[B]" or "[ ]"
  local italic_indicator = state.current.italic and "[I]" or "[ ]"

  cb:blank()

  -- Build info line using spans for styling
  -- Note: "Original" and "Current" text will get color swatch highlights applied separately
  cb:spans({
    { text = "  Original", style = "label" },
    { text = "   ", style = "muted" },
    { text = "Current", style = "label" },
    { text = "   " .. fg_bg_mode .. " ", style = "muted" },
    { text = bold_indicator .. " bold ", style = state.current.bold and "emphasis" or "muted" },
    { text = italic_indicator .. " italic", style = state.current.italic and "emphasis" or "muted" },
  })

  cb:blank()

  -- Color mode and alpha info
  local color_mode_display = state.color_mode:upper()
  local alpha_display = state.alpha_enabled
    and string.format("  A: %d%%", math.floor(state.alpha + 0.5))
    or ""

  cb:spans({
    { text = "  Mode: ", style = "label" },
    { text = color_mode_display, style = "value" },
    { text = " (m)", style = "muted" },
    { text = alpha_display, style = state.alpha < 100 and "emphasis" or "muted" },
    { text = "  Step: ", style = "label" },
    { text = get_step_label(), style = "value" },
    { text = " (-/+)", style = "muted" },
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

-- ============================================================================
-- Multipanel Layout and Rendering
-- ============================================================================

-- Forward declaration for schedule_render_multipanel
local schedule_render_multipanel

---Create layout configuration for multipanel mode
---@return MultiPanelConfig
local function create_layout_config()
  local ui = vim.api.nvim_list_uis()[1]
  local is_narrow = ui.width < MIN_SIDE_BY_SIDE_WIDTH

  -- Calculate grid panel size based on available space
  local grid_content_height = HEADER_HEIGHT + 11 + 1 + (PREVIEW_HEIGHT + PREVIEW_BORDERS) + FOOTER_HEIGHT

  if is_narrow then
    -- Stacked layout (vertical split): Grid on top, Info below
    return {
      layout = {
        split = "vertical",
        children = {
          {
            name = "grid",
            title = "Color Grid",
            ratio = 0.70,
            min_height = grid_content_height,
            focusable = true,
            cursorline = false,
            filetype = "ssns-colorpicker-grid",
          },
          {
            name = "info",
            title = "Info",
            ratio = 0.30,
            min_height = INFO_PANEL_MIN_HEIGHT,
            focusable = true,
            cursorline = false,
            filetype = "ssns-colorpicker-info",
          },
        }
      },
      total_width_ratio = 0.95,
      total_height_ratio = 0.85,
    }
  else
    -- Side-by-side layout (horizontal split): Grid left, Info right
    return {
      layout = {
        split = "horizontal",
        children = {
          {
            name = "grid",
            title = "Color Grid",
            ratio = 0.60,
            min_width = 40,
            focusable = true,
            cursorline = false,
            filetype = "ssns-colorpicker-grid",
          },
          {
            name = "info",
            title = "Info",
            ratio = 0.40,
            min_width = INFO_PANEL_MIN_WIDTH,
            focusable = true,
            cursorline = false,
            filetype = "ssns-colorpicker-info",
          },
        }
      },
      total_width_ratio = 0.80,
      total_height_ratio = 0.75,
    }
  end
end

---Render the grid panel content (header, grid, preview, footer)
---@param multi_state MultiPanelState
---@return string[] lines
---@return table[] highlights
local function render_grid_panel(multi_state)
  if not state then return {}, {} end

  local all_lines = {}
  local all_highlights = {}
  local line_offset = 0

  -- Get panel dimensions for grid calculation
  local panel = multi_state.panels["grid"]
  if not panel or not panel.float or not panel.float:is_valid() then
    return {}, {}
  end

  local panel_width = panel.rect.width
  local panel_height = panel.rect.height

  -- Recalculate grid size for this panel
  local grid_width, grid_height = calculate_grid_size(panel_width, panel_height)
  state.grid_width = grid_width
  state.grid_height = grid_height

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

  -- 3. Preview (custom rendering - dynamic foreground color with alpha)
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

  -- Store swatch info in state for post-render highlight application
  state._swatch_info = swatch_info
  state._footer_start_line = footer_start_line

  return all_lines, all_highlights
end

---Apply grid panel post-render highlights (color swatches)
---@param multi_state MultiPanelState
local function apply_grid_panel_highlights(multi_state)
  if not state or not state._swatch_info then return end

  local panel = multi_state.panels["grid"]
  if not panel or not panel.float or not panel.float:is_valid() then return end

  -- Temporarily update state.buf to point to grid panel buffer
  local original_buf = state.buf
  local original_ns = state.ns
  state.buf = panel.float.bufnr
  state.ns = panel.namespace

  -- Apply swatch highlights
  apply_swatch_highlights(state._footer_start_line, state._swatch_info)

  -- Restore original buf/ns
  state.buf = original_buf
  state.ns = original_ns
end

---Render the info panel content using ContentBuilder with interactive inputs
---@param multi_state MultiPanelState
---@return string[] lines
---@return table[] highlights
local function render_info_panel(multi_state)
  if not state then return {}, {} end

  local cb = ContentBuilder.new()

  -- Get current color hex
  local current_hex = get_active_color()

  -- Mode selector line
  cb:blank()
  cb:spans({
    { text = "  Mode: ", style = "label" },
    { text = "[" .. state.color_mode:upper() .. "]", style = "value" },
    { text = "  m", style = "key" },
  })

  cb:blank()

  -- Hex value input (include alpha as #RRGGBBAA when alpha is enabled)
  local hex_display = current_hex
  if state.alpha_enabled and state.color_mode ~= "cmyk" then
    local alpha_byte = math.floor((state.alpha / 100) * 255 + 0.5)
    hex_display = current_hex .. string.format("%02X", alpha_byte)
  end
  cb:input("hex", {
    label = "  Hex",
    value = hex_display,
    width = 10,
    placeholder = "#000000",
  })

  cb:blank()

  -- Separator
  cb:styled("  " .. string.rep("─", 16), "muted")

  cb:blank()

  -- Color components based on mode - use input fields for each
  local components = ColorUtils.get_color_components(current_hex, state.color_mode)
  for _, comp in ipairs(components) do
    local formatted = ColorUtils.format_value(comp.value, comp.unit, state.value_format)
    local input_key = "comp_" .. comp.label:lower()
    cb:input(input_key, {
      label = "  " .. comp.label,
      value = formatted,
      width = 8,
      placeholder = "0",
    })
  end

  -- Alpha input (if enabled and not CMYK)
  if state.alpha_enabled and state.color_mode ~= "cmyk" then
    cb:blank()
    local alpha_formatted = ColorUtils.format_value(state.alpha, "pct", state.value_format)
    cb:input("alpha", {
      label = "  A",
      value = alpha_formatted,
      width = 8,
      placeholder = "100%",
    })
  end

  cb:blank()

  -- Separator
  cb:styled("  " .. string.rep("─", 16), "muted")

  cb:blank()

  -- Format toggle
  local format_label = state.value_format == "standard" and "Standard" or "Decimal"
  cb:spans({
    { text = "  Format: ", style = "label" },
    { text = format_label, style = "value" },
    { text = "  f", style = "key" },
  })

  cb:blank()

  -- Style toggles
  local mode_ind = state.editing_bg and "[bg]" or "[fg]"
  local bold_ind = state.current.bold and "[B]" or "[ ]"
  local italic_ind = state.current.italic and "[I]" or "[ ]"

  cb:spans({
    { text = "  " .. mode_ind, style = "muted" },
  })

  cb:spans({
    { text = "  " .. bold_ind .. " bold", style = state.current.bold and "emphasis" or "muted" },
  })

  cb:spans({
    { text = "  " .. italic_ind .. " italic", style = state.current.italic and "emphasis" or "muted" },
  })

  -- Store ContentBuilder in state for InputManager to access
  state._info_panel_cb = cb

  return cb:build_lines(), cb:build_highlights()
end

---Get validation settings for color picker inputs based on current mode
---@return table<string, table> settings_map Map of input key -> validation settings
local function get_input_validation_settings()
  if not state then return {} end

  local settings = {}

  -- Hex input: allow hex characters
  settings["hex"] = {
    value_type = "text",
    input_pattern = "[%x#]",  -- Allow hex digits and #
  }

  -- Alpha input: 0-100 (or 0-1 for decimal mode)
  if state.alpha_enabled then
    if state.value_format == "decimal" then
      settings["alpha"] = {
        value_type = "float",
        min_value = 0,
        max_value = 1,
        allow_negative = false,
      }
    else
      settings["alpha"] = {
        value_type = "integer",
        min_value = 0,
        max_value = 100,
        allow_negative = false,
      }
    end
  end

  -- Component inputs based on color mode
  if state.color_mode == "hsl" then
    if state.value_format == "decimal" then
      settings["comp_h"] = { value_type = "float", min_value = 0, max_value = 1, allow_negative = false }
      settings["comp_s"] = { value_type = "float", min_value = 0, max_value = 1, allow_negative = false }
      settings["comp_l"] = { value_type = "float", min_value = 0, max_value = 1, allow_negative = false }
    else
      settings["comp_h"] = { value_type = "integer", min_value = 0, max_value = 360, allow_negative = false }
      settings["comp_s"] = { value_type = "integer", min_value = 0, max_value = 100, allow_negative = false }
      settings["comp_l"] = { value_type = "integer", min_value = 0, max_value = 100, allow_negative = false }
    end
  elseif state.color_mode == "rgb" then
    if state.value_format == "decimal" then
      settings["comp_r"] = { value_type = "float", min_value = 0, max_value = 1, allow_negative = false }
      settings["comp_g"] = { value_type = "float", min_value = 0, max_value = 1, allow_negative = false }
      settings["comp_b"] = { value_type = "float", min_value = 0, max_value = 1, allow_negative = false }
    else
      settings["comp_r"] = { value_type = "integer", min_value = 0, max_value = 255, allow_negative = false }
      settings["comp_g"] = { value_type = "integer", min_value = 0, max_value = 255, allow_negative = false }
      settings["comp_b"] = { value_type = "integer", min_value = 0, max_value = 255, allow_negative = false }
    end
  elseif state.color_mode == "hsv" then
    if state.value_format == "decimal" then
      settings["comp_h"] = { value_type = "float", min_value = 0, max_value = 1, allow_negative = false }
      settings["comp_s"] = { value_type = "float", min_value = 0, max_value = 1, allow_negative = false }
      settings["comp_v"] = { value_type = "float", min_value = 0, max_value = 1, allow_negative = false }
    else
      settings["comp_h"] = { value_type = "integer", min_value = 0, max_value = 360, allow_negative = false }
      settings["comp_s"] = { value_type = "integer", min_value = 0, max_value = 100, allow_negative = false }
      settings["comp_v"] = { value_type = "integer", min_value = 0, max_value = 100, allow_negative = false }
    end
  elseif state.color_mode == "cmyk" then
    if state.value_format == "decimal" then
      settings["comp_c"] = { value_type = "float", min_value = 0, max_value = 1, allow_negative = false }
      settings["comp_m"] = { value_type = "float", min_value = 0, max_value = 1, allow_negative = false }
      settings["comp_y"] = { value_type = "float", min_value = 0, max_value = 1, allow_negative = false }
      settings["comp_k"] = { value_type = "float", min_value = 0, max_value = 1, allow_negative = false }
    else
      settings["comp_c"] = { value_type = "integer", min_value = 0, max_value = 100, allow_negative = false }
      settings["comp_m"] = { value_type = "integer", min_value = 0, max_value = 100, allow_negative = false }
      settings["comp_y"] = { value_type = "integer", min_value = 0, max_value = 100, allow_negative = false }
      settings["comp_k"] = { value_type = "integer", min_value = 0, max_value = 100, allow_negative = false }
    end
  end

  return settings
end

---Update InputManager validation settings (call when color mode or format changes)
local function update_input_validation_settings()
  if not state or not state._info_input_manager then return end
  local settings = get_input_validation_settings()
  state._info_input_manager:update_all_input_settings(settings)
end

---Render all multipanel panels
local function render_multipanel()
  if not state or not state._multipanel then return end

  local multi = state._multipanel

  -- Render grid panel
  multi:render_panel("grid")

  -- Apply post-render highlights for grid panel
  apply_grid_panel_highlights(multi)

  -- Render info panel
  multi:render_panel("info")

  -- Sync InputManager with new values after render
  -- (InputManager keeps its own copy of values, so we need to update when color changes)
  if state._info_input_manager and state._info_panel_cb then
    local cb = state._info_panel_cb
    state._info_input_manager:update_inputs(
      cb:get_inputs(),
      cb:get_input_order()
    )
    -- Update validation settings (in case color mode or format changed)
    update_input_validation_settings()
  end

  -- Trigger on_change callback
  if state.options.on_change then
    state.options.on_change(vim.deepcopy(state.current))
  end
end

---Schedule a render for multipanel mode
schedule_render_multipanel = function()
  if not state or not state._multipanel then return end

  -- If render already pending, skip
  if state._render_pending then return end

  state._render_pending = true
  vim.schedule(function()
    if state and state._multipanel then
      state._render_pending = false
      render_multipanel()
    end
  end)
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
  if not state then return end

  -- Use multipanel render if in multipanel mode
  if state._multipanel then
    schedule_render_multipanel()
    return
  end

  -- Single-window mode
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
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

---Cycle through color modes (HSL → RGB → CMYK → HSV → HSL)
local function cycle_mode()
  if not state then return end

  -- Don't allow cycling if mode is forced
  if state.options.forced_mode then
    vim.notify("Color mode is locked to " .. state.options.forced_mode:upper(), vim.log.levels.INFO)
    return
  end

  -- Find current mode index and cycle to next
  local current_idx = 1
  for i, mode in ipairs(COLOR_MODES) do
    if mode == state.color_mode then
      current_idx = i
      break
    end
  end

  local next_idx = (current_idx % #COLOR_MODES) + 1
  state.color_mode = COLOR_MODES[next_idx]
  schedule_render()
end

---Cycle value display format (standard ↔ decimal)
local function cycle_format()
  if not state then return end
  state.value_format = state.value_format == "standard" and "decimal" or "standard"
  schedule_render()
end

---Adjust alpha value
---@param delta number Amount to change alpha (positive or negative)
local function adjust_alpha(delta)
  if not state then return end

  -- Only adjust if alpha is enabled and mode supports it
  if not state.alpha_enabled then
    vim.notify("Alpha editing is not enabled", vim.log.levels.INFO)
    return
  end

  if state.color_mode == "cmyk" then
    vim.notify("CMYK mode does not support alpha", vim.log.levels.INFO)
    return
  end

  local step = delta * BASE_STEP_SATURATION * get_step_multiplier()
  state.alpha = math.max(0, math.min(100, state.alpha + step))
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
  local controls = {
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
      header = "Color Mode",
      keys = {
        { key = "m", desc = "Cycle mode (HSL/RGB/CMYK/HSV)" },
        { key = "f", desc = "Toggle format (standard/decimal)" },
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

  -- Add alpha controls if enabled
  if state and state.alpha_enabled then
    table.insert(controls, 4, {
      header = "Alpha",
      keys = {
        { key = "a / A", desc = "Decrease/increase opacity" },
      }
    })
  end

  return controls
end

---Show the help popup using UiFloat's controls system
local function show_help()
  if not state then return end

  -- Use multipanel's show_controls if in multipanel mode
  if state._multipanel then
    state._multipanel:show_controls(get_controls_definition())
    return
  end

  -- Single-window mode
  if state._float then
    state._float:show_controls(get_controls_definition())
  end
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

  -- Color mode and format cycling
  add_maps(get_key("cycle_mode", "m"), cycle_mode, keymaps)
  add_maps(get_key("cycle_format", "f"), cycle_format, keymaps)

  -- Alpha adjustment (with count support)
  add_maps(get_key("alpha_up", "A"), function()
    local count = vim.v.count1
    adjust_alpha(count)
  end, keymaps)

  add_maps(get_key("alpha_down", "a"), function()
    local count = vim.v.count1
    adjust_alpha(-count)
  end, keymaps)

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
  local multipanel = state._multipanel
  local input_manager = state._info_input_manager

  -- Clean up InputManager before clearing state
  if input_manager then
    input_manager:destroy()
  end

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

  -- Close multipanel if in multipanel mode
  if multipanel and multipanel:is_valid() then
    multipanel:close()
    return
  end

  -- Close the floating window using UiFloat (single-window mode)
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
    -- New fields for color mode and alpha support
    color_mode = options.forced_mode or "hsl",  -- Default to HSL
    value_format = "standard",  -- "standard" or "decimal"
    alpha = options.initial_alpha or 100,  -- 0-100, default fully opaque
    alpha_enabled = options.alpha_enabled or false,
    focused_panel = "grid",  -- Start with grid focused
    _multipanel = nil,  -- Will be set when multipanel mode is enabled
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

---Setup keymaps for multipanel mode
---@param multi MultiPanelState
local function setup_multipanel_keymaps(multi)
  if not state then return end

  local cfg = Config.get().keymaps.colorpicker or {}

  -- Helper to get key(s) from config with fallback
  local function get_key(name, default)
    return cfg[name] or default
  end

  -- Grid-only keymaps (navigation that only works on the color grid panel)
  local grid_keymaps = {}

  -- Navigation with count support - GRID PANEL ONLY
  local nav_left = get_key("nav_left", "h")
  local nav_right = get_key("nav_right", "l")
  local nav_up = get_key("nav_up", "k")
  local nav_down = get_key("nav_down", "j")
  local sat_up = get_key("sat_up", "K")
  local sat_down = get_key("sat_down", "J")

  grid_keymaps[nav_left] = function()
    local count = vim.v.count1
    shift_hue(-count)
  end
  grid_keymaps[nav_right] = function()
    local count = vim.v.count1
    shift_hue(count)
  end
  grid_keymaps[nav_up] = function()
    local count = vim.v.count1
    shift_lightness(count)
  end
  grid_keymaps[nav_down] = function()
    local count = vim.v.count1
    shift_lightness(-count)
  end
  grid_keymaps[sat_up] = function()
    local count = vim.v.count1
    shift_saturation(count)
  end
  grid_keymaps[sat_down] = function()
    local count = vim.v.count1
    shift_saturation(-count)
  end

  -- Step size adjustment - also grid-only
  grid_keymaps[get_key("step_down", "-")] = decrease_step_size
  local step_up_keys = get_key("step_up", { "+", "=" })
  if type(step_up_keys) == "table" then
    for _, k in ipairs(step_up_keys) do
      grid_keymaps[k] = increase_step_size
    end
  else
    grid_keymaps[step_up_keys] = increase_step_size
  end

  -- Apply grid-only keymaps to grid panel
  multi:set_panel_keymaps("grid", grid_keymaps)

  -- Common keymaps for all panels (actions, toggles, etc.)
  local common_keymaps = {}

  -- Toggles
  common_keymaps[get_key("toggle_bold", "b")] = toggle_bold
  common_keymaps[get_key("toggle_italic", "i")] = toggle_italic
  common_keymaps[get_key("toggle_bg", "B")] = toggle_bg_mode
  common_keymaps[get_key("clear_bg", "x")] = clear_bg

  -- Actions
  common_keymaps[get_key("reset", "r")] = reset_color
  common_keymaps[get_key("hex_input", "#")] = enter_hex_input
  common_keymaps[get_key("apply", "<CR>")] = apply

  -- Cancel keymaps
  local cancel_keys = get_key("cancel", { "q", "<Esc>" })
  if type(cancel_keys) == "table" then
    for _, k in ipairs(cancel_keys) do
      common_keymaps[k] = cancel
    end
  else
    common_keymaps[cancel_keys] = cancel
  end

  -- Help
  common_keymaps[get_key("help", "?")] = show_help

  -- Color mode and format cycling
  common_keymaps[get_key("cycle_mode", "m")] = cycle_mode
  common_keymaps[get_key("cycle_format", "f")] = cycle_format

  -- Alpha adjustment (with count support)
  common_keymaps[get_key("alpha_up", "A")] = function()
    local count = vim.v.count1
    adjust_alpha(count)
  end
  common_keymaps[get_key("alpha_down", "a")] = function()
    local count = vim.v.count1
    adjust_alpha(-count)
  end

  -- Focus switching
  common_keymaps[get_key("focus_next", "<Tab>")] = function()
    multi:focus_next_panel()
  end
  common_keymaps[get_key("focus_prev", "<S-Tab>")] = function()
    multi:focus_prev_panel()
  end

  -- Apply common keymaps to all panels
  multi:set_keymaps(common_keymaps)
end

---Extract numeric value from a string, stripping all non-numeric characters
---Handles integers, decimals, and negative numbers
---@param str string The input string
---@return number|nil value The extracted number, or nil if no valid number found
local function extract_number(str)
  if not str or str == "" then return nil end
  -- Match optional negative sign, digits, optional decimal point and more digits
  local num_str = str:match("%-?%d+%.?%d*")
  if not num_str or num_str == "" or num_str == "-" or num_str == "." then
    return nil
  end
  return tonumber(num_str)
end

---Extract hex digits from a string
---@param str string The input string
---@return string|nil hex_digits Only the hex digit characters, or nil if none found
local function extract_hex_digits(str)
  if not str or str == "" then return nil end
  -- Remove # prefix if present, then extract only hex digits
  local cleaned = str:gsub("^#", "")
  local hex_only = cleaned:gsub("[^%x]", "")
  if hex_only == "" then return nil end
  return hex_only
end

---Handle input commit from the info panel (called on Enter, not on every keystroke)
---Parses hex values or component values and updates the color
---@param key string Input field key (e.g., "hex", "comp_h", "comp_s", "comp_l", "alpha")
---@param value string The committed input value
local function handle_input_commit(key, value)
  if not state then return end

  -- Trim whitespace
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  if value == "" then return end

  if key == "hex" then
    -- Extract only hex digits from the input
    local hex_digits = extract_hex_digits(value)
    if not hex_digits then return end

    if #hex_digits >= 6 then
      -- Take first 6 digits for color
      local color_hex = "#" .. hex_digits:sub(1, 6):upper()
      if ColorUtils.is_valid_hex(color_hex) then
        set_active_color(color_hex)

        -- If 8 digits provided, parse alpha from last 2 hex digits
        if #hex_digits >= 8 and state.alpha_enabled then
          local alpha_hex = hex_digits:sub(7, 8)
          local alpha_byte = tonumber(alpha_hex, 16)
          if alpha_byte then
            state.alpha = (alpha_byte / 255) * 100
          end
        end
        schedule_render()
      end
    end
  elseif key == "alpha" then
    -- Extract numeric value from alpha input
    local num = extract_number(value)
    if num and state.alpha_enabled then
      -- Handle decimal format (0-1) vs standard (0-100)
      if state.value_format == "decimal" and num >= 0 and num <= 1 then
        state.alpha = num * 100
      else
        state.alpha = math.max(0, math.min(100, num))
      end
      schedule_render()
    end
  elseif key:match("^comp_") then
    -- Parse color component value
    local comp_name = key:gsub("^comp_", ""):upper()
    local current_hex = get_active_color()

    -- Extract numeric value (strips °, %, and any other non-numeric chars)
    local num = extract_number(value)
    if not num then return end

    -- Handle decimal format conversion for percentage-based values
    if state.value_format == "decimal" and num >= 0 and num <= 1 then
      -- Convert 0-1 decimal to appropriate range
      if comp_name == "H" then
        -- Hue in decimal is 0-1 representing 0-360
        num = num * 360
      elseif state.color_mode == "rgb" then
        -- RGB in decimal is 0-1 representing 0-255
        num = num * 255
      else
        -- S, L, V, C, M, Y, K are percentages (0-100)
        num = num * 100
      end
    end

    -- Update color based on mode and component
    local new_hex = nil
    if state.color_mode == "hsl" then
      local h, s, l = ColorUtils.hex_to_hsl(current_hex)
      if comp_name == "H" then
        h = math.max(0, math.min(360, num))
      elseif comp_name == "S" then
        s = math.max(0, math.min(100, num))
      elseif comp_name == "L" then
        l = math.max(0, math.min(100, num))
      end
      new_hex = ColorUtils.hsl_to_hex(h, s, l)
    elseif state.color_mode == "rgb" then
      local r, g, b = ColorUtils.hex_to_rgb(current_hex)
      if comp_name == "R" then
        r = math.max(0, math.min(255, math.floor(num + 0.5)))
      elseif comp_name == "G" then
        g = math.max(0, math.min(255, math.floor(num + 0.5)))
      elseif comp_name == "B" then
        b = math.max(0, math.min(255, math.floor(num + 0.5)))
      end
      new_hex = ColorUtils.rgb_to_hex(r, g, b)
    elseif state.color_mode == "hsv" then
      local h, s, v = ColorUtils.hex_to_hsv(current_hex)
      if comp_name == "H" then
        h = math.max(0, math.min(360, num))
      elseif comp_name == "S" then
        s = math.max(0, math.min(100, num))
      elseif comp_name == "V" then
        v = math.max(0, math.min(100, num))
      end
      new_hex = ColorUtils.hsv_to_hex(h, s, v)
    elseif state.color_mode == "cmyk" then
      local c, m, y, k = ColorUtils.hex_to_cmyk(current_hex)
      if comp_name == "C" then
        c = math.max(0, math.min(100, num))
      elseif comp_name == "M" then
        m = math.max(0, math.min(100, num))
      elseif comp_name == "Y" then
        y = math.max(0, math.min(100, num))
      elseif comp_name == "K" then
        k = math.max(0, math.min(100, num))
      end
      new_hex = ColorUtils.cmyk_to_hex(c, m, y, k)
    end

    if new_hex then
      set_active_color(new_hex)
      -- Update saved_hsl so grid reflects changes
      if state.saved_hsl then
        local h, s, _ = ColorUtils.hex_to_hsl(new_hex)
        state.saved_hsl.h = h
        state.saved_hsl.s = s
      end
      schedule_render()
    end
  end
end

---Create and setup InputManager for info panel
---@param multi MultiPanelState
local function setup_info_panel_input_manager(multi)
  if not state or not state._info_panel_cb then return end

  local info_panel = multi.panels["info"]
  if not info_panel or not info_panel.float or not info_panel.float:is_valid() then
    return
  end

  local bufnr = info_panel.float.bufnr
  local winid = info_panel.float.winid
  local cb = state._info_panel_cb

  -- Create InputManager with inputs from ContentBuilder
  -- Use on_input_exit to only process values when Enter is pressed (not on every keystroke)
  state._info_input_manager = InputManager.new({
    bufnr = bufnr,
    winid = winid,
    inputs = cb:get_inputs(),
    input_order = cb:get_input_order(),
    on_input_exit = function(key)
      -- Get the validated value from the InputManager when exiting input mode
      local value = state._info_input_manager:get_validated_value(key)
      if value and value ~= "" then
        handle_input_commit(key, value)
      end
    end,
  })

  -- Setup input handling
  state._info_input_manager:setup()

  -- Initialize highlights for inputs
  state._info_input_manager:init_highlights()

  -- Apply validation settings based on current color mode
  update_input_validation_settings()

  -- Remove Tab/S-Tab keymaps from InputManager so multipanel Tab navigation works
  -- (j/k already handles input navigation within the info panel)
  pcall(vim.keymap.del, 'n', '<Tab>', { buffer = bufnr })
  pcall(vim.keymap.del, 'n', '<S-Tab>', { buffer = bufnr })
  pcall(vim.keymap.del, 'i', '<Tab>', { buffer = bufnr })
  pcall(vim.keymap.del, 'i', '<S-Tab>', { buffer = bufnr })

  -- Re-apply multipanel Tab keymaps to the info panel buffer
  local opts = { buffer = bufnr, nowait = true, silent = true }
  vim.keymap.set('n', '<Tab>', function()
    multi:focus_next_panel()
  end, opts)
  vim.keymap.set('n', '<S-Tab>', function()
    multi:focus_prev_panel()
  end, opts)
end

---Show the color picker in multipanel mode with info panel
---@param options ColorPickerOptions
function ColorPicker.show_multipanel(options)
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

  -- Pre-compute initial HSL for color band memory
  local initial_hsl = nil
  if initial.fg then
    local h, s, _ = ColorUtils.hex_to_hsl(initial.fg)
    initial_hsl = { h = h, s = s }
  end

  -- Create layout config
  local layout_config = create_layout_config()

  -- Add render callbacks to layout config
  layout_config.layout.children[1].on_render = render_grid_panel
  layout_config.layout.children[2].on_render = render_info_panel

  -- Add focus callbacks (guard against state being nil during initial create)
  layout_config.layout.children[1].on_focus = function(multi_state)
    if state then state.focused_panel = "grid" end
    multi_state:update_panel_title("grid", "Color Grid ●")
    multi_state:update_panel_title("info", "Info")
  end

  layout_config.layout.children[1].on_blur = function(multi_state)
    multi_state:update_panel_title("grid", "Color Grid")
  end

  layout_config.layout.children[2].on_focus = function(multi_state)
    if state then state.focused_panel = "info" end
    multi_state:update_panel_title("info", "Info ●")
    multi_state:update_panel_title("grid", "Color Grid")
    -- Focus the first input field when info panel receives focus
    if state and state._info_input_manager then
      vim.schedule(function()
        if state and state._info_input_manager then
          state._info_input_manager:focus_first_field()
        end
      end)
    end
  end

  layout_config.layout.children[2].on_blur = function(multi_state)
    multi_state:update_panel_title("info", "Info")
  end

  -- Add controls for help popup
  layout_config.controls = get_controls_definition()
  layout_config.footer = "? = Controls"
  layout_config.initial_focus = "grid"
  layout_config.augroup_name = "SSNSColorPickerMulti"

  -- Add on_close callback
  layout_config.on_close = function()
    state = nil
  end

  -- Create multipanel window
  local multi = MultiPanel.create(UiFloat, layout_config)

  if not multi or not multi:is_valid() then
    vim.notify("ColorPicker: Failed to create multipanel window", vim.log.levels.ERROR)
    return
  end

  -- Get grid panel buffer for state
  local grid_panel = multi.panels["grid"]
  local grid_buf = grid_panel and grid_panel.float and grid_panel.float.bufnr
  local grid_win = grid_panel and grid_panel.float and grid_panel.float.winid

  -- Calculate initial grid size from grid panel
  local grid_width, grid_height = 21, 9  -- Defaults
  if grid_panel and grid_panel.rect then
    grid_width, grid_height = calculate_grid_size(grid_panel.rect.width, grid_panel.rect.height)
  end

  -- Initialize state
  state = {
    current = vim.deepcopy(initial),
    original = vim.deepcopy(initial),
    editing_bg = false,
    grid_width = grid_width,
    grid_height = grid_height,
    win = grid_win,  -- Primary window is grid panel
    buf = grid_buf,  -- Primary buffer is grid panel
    ns = vim.api.nvim_create_namespace("ssns_color_picker_multi"),
    options = options,
    saved_hsl = initial_hsl,
    step_index = DEFAULT_STEP_INDEX,
    lightness_virtual = nil,
    saturation_virtual = nil,
    _float = nil,  -- Not used in multipanel mode
    _multipanel = multi,  -- Reference to multipanel window
    color_mode = options.forced_mode or "hsl",
    value_format = "standard",
    alpha = options.initial_alpha or 100,
    alpha_enabled = options.alpha_enabled or false,
    focused_panel = "grid",
    _render_pending = false,
  }

  -- Setup keymaps for multipanel
  setup_multipanel_keymaps(multi)

  -- Initial render
  render_multipanel()

  -- Setup InputManager for info panel after initial render
  -- This must happen after render_multipanel() populates state._info_panel_cb
  setup_info_panel_input_manager(multi)
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
