---@class ThemeEditorRender
---Rendering functions for the theme editor
local M = {}

local ContentBuilder = require('nvim-float.content')
local Data = require('ssns.ui.panels.theme_editor_data')
local PreviewSql = require('ssns.ui.panels.theme_preview_sql')

-- ============================================================================
-- Themes Panel (Left)
-- ============================================================================

---Render a single theme entry with element tracking
---@param cb any ContentBuilder
---@param theme table Theme data
---@param original_idx number Original index in available_themes
local function render_theme_entry(cb, theme, original_idx)
  cb:spans({
    { text = "   " },
    {
      text = theme.display_name,
      track = {
        name = "theme_" .. (theme.name or "default"),
        type = "theme",
        data = { theme = theme, index = original_idx },
        row_based = true,
      },
    },
  })
end

---Render the themes list panel
---Order: Default, User Themes (if any), Built-in Themes
---@param state ThemeEditorState
---@return string[] lines, table[] highlights, ContentBuilder cb
function M.render_themes(state)
  local cb = ContentBuilder.new()

  if not state then
    return cb:build_lines(), cb:build_highlights(), cb
  end

  cb:blank()

  -- Separate themes into categories while preserving original indices
  local default_theme = nil
  local default_idx = nil
  local user_themes = {}
  local builtin_themes = {}

  for i, theme in ipairs(state.available_themes) do
    if theme.is_default then
      default_theme = theme
      default_idx = i
    elseif theme.is_user then
      table.insert(user_themes, { theme = theme, idx = i })
    else
      table.insert(builtin_themes, { theme = theme, idx = i })
    end
  end

  -- Render Default first
  if default_theme then
    render_theme_entry(cb, default_theme, default_idx)
  end

  -- Render User Themes section (if any)
  if #user_themes > 0 then
    cb:blank()
    cb:styled(" ─── User Themes ───", "muted")
    cb:blank()

    for _, entry in ipairs(user_themes) do
      render_theme_entry(cb, entry.theme, entry.idx)
    end
  end

  -- Render Built-in section
  cb:blank()
  cb:styled(" ─── Built-in ───", "muted")
  cb:blank()

  for _, entry in ipairs(builtin_themes) do
    render_theme_entry(cb, entry.theme, entry.idx)
  end

  cb:blank()

  return cb:build_lines(), cb:build_highlights(), cb
end

-- ============================================================================
-- Colors Panel (Middle)
-- ============================================================================

---Format a color value for display
---@param color_def table? Color definition {fg, bg, bold, italic, etc.}
---@return string formatted_value
local function format_color_value(color_def)
  if not color_def or type(color_def) ~= "table" then
    return "─"
  end

  local parts = {}

  if color_def.fg then
    table.insert(parts, color_def.fg)
  end

  if color_def.bg then
    table.insert(parts, "bg:" .. color_def.bg)
  end

  local modifiers = {}
  if color_def.bold then table.insert(modifiers, "B") end
  if color_def.italic then table.insert(modifiers, "I") end
  if color_def.underline then table.insert(modifiers, "U") end

  if #modifiers > 0 then
    table.insert(parts, "[" .. table.concat(modifiers) .. "]")
  end

  if #parts == 0 then
    return "─"
  end

  return table.concat(parts, " ")
end

---Render the colors panel
---@param state ThemeEditorState
---@return string[] lines, table[] highlights, ContentBuilder cb
function M.render_colors(state)
  local cb = ContentBuilder.new()

  if not state or not state.current_colors then
    return cb:build_lines(), cb:build_highlights(), cb
  end

  cb:blank()

  local current_category = nil

  for i, def in ipairs(Data.COLOR_DEFINITIONS) do
    -- Add category header if new category
    if def.category ~= current_category then
      if current_category ~= nil then
        cb:blank()
      end
      cb:styled(string.format(" ─── %s ───", def.category), "section")
      cb:blank()
      current_category = def.category
    end

    local color_value = state.current_colors[def.key]
    local display_value = format_color_value(color_value)

    -- Format: "  ▸ Color Name        #HEXVAL [BI]"
    local name_width = 18
    local padded_name = def.name .. string.rep(" ", math.max(0, name_width - #def.name))

    -- Create a color swatch indicator using the actual color
    local swatch = "●"
    local swatch_hl = nil
    if color_value and color_value.fg then
      -- We'll create a dynamic highlight for the swatch
      swatch_hl = "ThemeEditorSwatch" .. i
    end

    -- Track this color element for cursor-based queries
    -- Row-based tracking means the entire line is this element
    cb:spans({
      { text = "   " },
      {
        text = padded_name,
        style = "label",
        track = {
          name = "color_" .. def.key,
          type = "color",
          data = { def = def, index = i },
          row_based = true,
        },
      },
      { text = swatch, hl_group = swatch_hl or "NvimFloatHint" },
      { text = " " },
      { text = display_value, style = "muted" },
    })
  end

  cb:blank()

  return cb:build_lines(), cb:build_highlights(), cb
end

-- ============================================================================
-- Preview Panel (Right)
-- ============================================================================

---Render the preview panel
---Uses PreviewSql module for consistent preview across theme picker and editor
---@param state ThemeEditorState
---@return string[] lines, table[] highlights
function M.render_preview(state)
  -- Use pre-defined highlights from PreviewSql (no parser needed)
  return PreviewSql.build()
end

-- ============================================================================
-- Color Swatch Highlights
-- ============================================================================

-- Namespace for swatch extmarks
local swatch_ns = vim.api.nvim_create_namespace("ssns_theme_editor_swatch")

---Apply color swatch highlights to the colors buffer
---The colors panel uses a bg-only CursorLine so swatch fg colors show through
---@param bufnr number Buffer number for the colors panel
---@param state ThemeEditorState
function M.apply_swatch_highlights(bufnr, state)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end
  if not state or not state.current_colors then return end

  -- Clear previous extmarks
  vim.api.nvim_buf_clear_namespace(bufnr, swatch_ns, 0, -1)

  -- Get all lines from the buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local current_category = nil
  local line_idx = 1  -- Start after initial blank line (0-indexed: line 1)
  local swatch_char = "●"
  local swatch_bytes = #swatch_char  -- 3 bytes for "●"

  for i, def in ipairs(Data.COLOR_DEFINITIONS) do
    -- Account for category headers (same logic as render_colors)
    if def.category ~= current_category then
      if current_category ~= nil then
        line_idx = line_idx + 1  -- Blank line before category
      end
      line_idx = line_idx + 1  -- Category header
      line_idx = line_idx + 1  -- Blank line after header
      current_category = def.category
    end

    local color_value = state.current_colors[def.key]
    if color_value and (color_value.fg or color_value.bg) then
      local hl_name = "ThemeEditorSwatch" .. i

      -- Define the highlight group
      local hl_def = {}
      if color_value.fg then
        hl_def.fg = color_value.fg
      end
      if color_value.bg then
        hl_def.bg = color_value.bg
      end
      vim.api.nvim_set_hl(0, hl_name, hl_def)

      -- Find the actual byte position of "●" in this line
      local line_text = lines[line_idx + 1]  -- lines is 1-indexed
      if line_text then
        local swatch_start = line_text:find(swatch_char, 1, true)
        if swatch_start then
          -- Convert to 0-indexed byte position
          local col_start = swatch_start - 1

          -- Apply highlight using extmark
          pcall(vim.api.nvim_buf_set_extmark, bufnr, swatch_ns, line_idx, col_start, {
            end_col = col_start + swatch_bytes,
            hl_group = hl_name,
          })
        end
      end
    end

    line_idx = line_idx + 1  -- Move to next color line
  end
end

---Clear swatch highlights
function M.clear_swatch_highlights()
  for i = 1, #Data.COLOR_DEFINITIONS do
    local hl_name = "ThemeEditorSwatch" .. i
    pcall(vim.api.nvim_set_hl, 0, hl_name, {})
  end
end

return M
