---@class ThemePicker
---Theme picker UI with live preview
local ThemePicker = {}

local UiFloat = require('ssns.ui.core.float')
local ContentBuilder = require('ssns.ui.core.content_builder')
local ThemeManager = require('ssns.ui.theme_manager')
local KeymapManager = require('ssns.keymap_manager')
local PreviewSql = require('ssns.ui.panels.theme_preview_sql')

---@type MultiPanelWindow? Current multi-panel window
local multi_panel = nil

---@type table UI state
local ui_state = {
  available_themes = {},
  original_theme = nil,
  selected_idx = 1,
  theme_line_map = {},
}

---Render themes list panel using ContentBuilder
---@param mp MultiPanelWindow
---@return string[] lines, table[] highlights
local function render_themes_list(mp)
  local cb = ContentBuilder.new()
  local themes = ui_state.available_themes
  local current = ThemeManager.get_current()

  cb:blank()

  local user_section_added = false
  local theme_line_map = {}

  for i, theme in ipairs(themes) do
    local is_selected = i == ui_state.selected_idx
    local is_current = (theme.name == current) or (theme.is_default and current == nil)

    -- Add separator after Default option
    if theme.is_default then
      theme_line_map[i] = cb:line_count()

      if is_selected then
        cb:spans({
          { text = " ▶ ", style = "emphasis" },
          { text = theme.display_name, style = "highlight" },
          { text = is_current and " ●" or "", style = "success" },
        })
      else
        cb:spans({
          { text = "   " },
          { text = theme.display_name },
          { text = is_current and " ●" or "", style = "success" },
        })
      end

      cb:blank()
      cb:styled(" ─── Built-in ───", "muted")
      cb:blank()
    elseif theme.is_user and not user_section_added then
      cb:blank()
      cb:styled(" ─── User Themes ───", "muted")
      cb:blank()
      user_section_added = true

      theme_line_map[i] = cb:line_count()

      if is_selected then
        cb:spans({
          { text = " ▶ ", style = "emphasis" },
          { text = theme.display_name, style = "highlight" },
          { text = is_current and " ●" or "", style = "success" },
        })
      else
        cb:spans({
          { text = "   " },
          { text = theme.display_name },
          { text = is_current and " ●" or "", style = "success" },
        })
      end
    else
      theme_line_map[i] = cb:line_count()

      if is_selected then
        cb:spans({
          { text = " ▶ ", style = "emphasis" },
          { text = theme.display_name, style = "highlight" },
          { text = is_current and " ●" or "", style = "success" },
        })
      else
        cb:spans({
          { text = "   " },
          { text = theme.display_name },
          { text = is_current and " ●" or "", style = "success" },
        })
      end
    end
  end

  cb:blank()

  -- Store line map for cursor positioning
  ui_state.theme_line_map = theme_line_map

  -- Position cursor on selected theme
  vim.schedule(function()
    if multi_panel then
      local cursor_line = theme_line_map[ui_state.selected_idx]
      if cursor_line then
        multi_panel:set_cursor("themes", cursor_line + 1, 0)
      end
    end
  end)

  return cb:build_lines(), cb:build_highlights()
end

---Render preview panel
---@param mp MultiPanelWindow
---@return string[] lines, table[] highlights
local function render_preview(mp)
  -- Use pre-defined highlights from PreviewSql (no parser needed)
  return PreviewSql.build()
end

---Handle theme selection change
local function on_selection_change()
  local theme = ui_state.available_themes[ui_state.selected_idx]
  if theme and multi_panel then
    ThemeManager.preview(theme.name)

    -- Re-render both panels to update highlighting and current marker
    multi_panel:render_panel("themes")
    multi_panel:render_panel("preview")
  end
end

---Navigate theme list
---@param direction number 1 for down, -1 for up
local function navigate_themes(direction)
  if not multi_panel then return end

  ui_state.selected_idx = ui_state.selected_idx + direction

  -- Wrap around
  if ui_state.selected_idx < 1 then
    ui_state.selected_idx = #ui_state.available_themes
  elseif ui_state.selected_idx > #ui_state.available_themes then
    ui_state.selected_idx = 1
  end

  -- Re-render and preview
  on_selection_change()
end

---Apply selected theme
local function apply_theme()
  if not multi_panel then return end

  local theme = ui_state.available_themes[ui_state.selected_idx]
  if theme then
    ThemeManager.set_theme(theme.name, true)
  end

  ThemePicker.close()
end

---Cancel and restore original theme
local function cancel_selection()
  if not multi_panel then return end

  -- Restore original theme
  ThemeManager.preview(ui_state.original_theme)

  ThemePicker.close()
end

---Show the theme picker UI
function ThemePicker.show()
  -- Close existing picker if open
  ThemePicker.close()

  -- Get available themes
  local themes = ThemeManager.get_available_themes()

  -- Add "Default" option at the top
  table.insert(themes, 1, {
    name = nil,
    display_name = "Default",
    description = "Use default colors from config",
    is_user = false,
    is_default = true,
  })

  -- Save current theme to restore on cancel
  ui_state.original_theme = ThemeManager.get_current()
  ui_state.available_themes = themes
  ui_state.theme_line_map = {}

  -- Find current theme index
  ui_state.selected_idx = 1
  if ui_state.original_theme then
    for i, theme in ipairs(themes) do
      if theme.name == ui_state.original_theme then
        ui_state.selected_idx = i
        break
      end
    end
  end

  local common = KeymapManager.get_group("common")

  -- Create multi-panel UI using UiFloat
  multi_panel = UiFloat.create_multi_panel({
    layout = {
      split = "horizontal",  -- Left and right columns
      children = {
        {
          name = "themes",
          title = "Themes",
          ratio = 0.25,
          on_render = render_themes_list,
          on_focus = function()
            if multi_panel then
              multi_panel:update_panel_title("themes", "Themes ●")
              multi_panel:update_panel_title("preview", "Preview")
            end
          end,
        },
        {
          name = "preview",
          title = "Preview",
          ratio = 0.75,
          cursorline = false,
          on_render = render_preview,
          on_create = function(bufnr)
            -- Mark buffer to skip semantic highlighting (we use pre-defined highlights)
            vim.b[bufnr].ssns_skip_semantic_highlight = true
          end,
          on_focus = function()
            if multi_panel then
              multi_panel:update_panel_title("themes", "Themes")
              multi_panel:update_panel_title("preview", "Preview ●")
            end
          end,
        },
      },
    },
    total_width_ratio = 0.80,
    total_height_ratio = 0.85,
    initial_focus = "themes",
    augroup_name = "SSNSThemePicker",
    controls = {
      {
        header = "Navigation",
        keys = {
          { key = "j/k", desc = "Navigate up/down" },
          { key = "Tab", desc = "Switch panels" },
          { key = "S-Tab", desc = "Previous panel" },
        },
      },
      {
        header = "Actions",
        keys = {
          { key = "Enter", desc = "Apply selected theme" },
          { key = "q/Esc", desc = "Cancel and restore" },
        },
      },
    },
    on_close = function()
      multi_panel = nil
      ui_state = {
        available_themes = {},
        original_theme = nil,
        selected_idx = 1,
        theme_line_map = {},
      }
    end,
  })

  if not multi_panel then
    return
  end

  -- Render all panels
  multi_panel:render_all()

  -- Setup keymaps for themes panel
  multi_panel:set_panel_keymaps("themes", {
    [common.close or "q"] = function() ThemePicker.close() end,
    [common.cancel or "<Esc>"] = cancel_selection,
    [common.nav_down or "j"] = function() navigate_themes(1) end,
    [common.nav_up or "k"] = function() navigate_themes(-1) end,
    [common.nav_down_alt or "<Down>"] = function() navigate_themes(1) end,
    [common.nav_up_alt or "<Up>"] = function() navigate_themes(-1) end,
    [common.confirm or "<CR>"] = apply_theme,
    [common.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [common.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
  })

  -- Setup keymaps for preview panel
  multi_panel:set_panel_keymaps("preview", {
    [common.close or "q"] = function() ThemePicker.close() end,
    [common.cancel or "<Esc>"] = cancel_selection,
    [common.confirm or "<CR>"] = apply_theme,
    [common.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [common.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
  })

  -- Preview selected theme
  on_selection_change()
end

---Close the theme picker
function ThemePicker.close()
  if not multi_panel then return end

  multi_panel:close()
  multi_panel = nil
end

---Check if theme picker is open
---@return boolean
function ThemePicker.is_open()
  return multi_panel ~= nil
end

return ThemePicker
