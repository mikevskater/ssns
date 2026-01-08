---@class ThemeEditor
---Interactive theme editor with three-panel layout:
---  Left: Theme list (built-in + user)
---  Middle: Color settings for selected theme
---  Right: Live SQL preview
local ThemeEditor = {}

local KeymapManager = require('ssns.keymap_manager')
local ThemeManager = require('ssns.ui.theme_manager')
local UiFloat = require('nvim-float.float')
local Data = require('ssns.ui.panels.theme_editor_data')
local Render = require('ssns.ui.panels.theme_editor_render')
local Actions = require('ssns.ui.panels.theme_picker_actions')
local colorpicker = require('nvim-colorpicker')

---@class ThemeEditorState
---@field available_themes table[] All available themes
---@field selected_theme_idx number Currently selected theme index
---@field selected_color_idx number Currently selected color index
---@field current_colors table Working copy of theme colors
---@field original_theme string? Original theme for cancel
---@field is_dirty boolean Whether colors have been modified
---@field editing_user_copy boolean Whether we auto-created a user copy

---@type MultiPanelWindow?
local multi_panel = nil

---@type ThemeEditorState?
local state = nil

-- ============================================================================
-- Internal Helpers
-- ============================================================================

---Get title for colors panel
---@param st ThemeEditorState
---@return string
local function get_colors_title(st)
  if not st then return "Colors" end
  local theme = st.available_themes[st.selected_theme_idx]
  if not theme then return "Colors" end

  local title = "Colors [" .. theme.display_name .. "]"
  if theme.is_user then
    title = title .. " (user)"
  end
  return title
end

---Load colors for the selected theme
---@param st ThemeEditorState
local function load_theme_colors(st)
  if not st then return end

  local theme = st.available_themes[st.selected_theme_idx]
  if not theme then return end

  if theme.is_default then
    -- Load base colors from config
    st.current_colors = ThemeManager.get_colors(nil)
  else
    -- Load theme colors (merged with base)
    st.current_colors = ThemeManager.get_colors(theme.name)
  end
end

---Apply current theme preview
local function apply_preview()
  if not state then return end

  local theme = state.available_themes[state.selected_theme_idx]
  if theme then
    ThemeManager.preview(theme.name)
  end

  -- Update swatch highlights
  if multi_panel then
    local colors_buf = multi_panel:get_panel_buffer("colors")
    if colors_buf then
      Render.apply_swatch_highlights(colors_buf, state)
    end
  end
end

-- ============================================================================
-- Navigation Actions
-- ============================================================================

---Navigate theme list
---@param direction number 1 for down, -1 for up
local function navigate_themes(direction)
  if not state or not multi_panel then return end

  -- Use visual order for navigation (Default, User, Built-in)
  state.selected_theme_idx = Render.get_next_theme_idx(state, state.selected_theme_idx, direction)

  -- Load theme colors
  load_theme_colors(state)
  state.is_dirty = false
  state.editing_user_copy = false

  -- Apply preview
  apply_preview()

  -- Re-render panels
  multi_panel:render_panel("themes")
  multi_panel:render_panel("colors")
  multi_panel:render_panel("preview")
  multi_panel:update_panel_title("colors", get_colors_title(state))

  -- Position cursor
  local cursor_line = Render.get_theme_cursor_line(state, state.selected_theme_idx)
  multi_panel:set_cursor("themes", cursor_line, 0)
end

---Select current theme and move to colors panel
local function select_theme()
  if not state or not multi_panel then return end

  -- Load theme colors
  load_theme_colors(state)

  -- Move to colors panel
  multi_panel:focus_panel("colors")
  local cursor_line = Render.get_color_cursor_line(state, state.selected_color_idx)
  multi_panel:set_cursor("colors", cursor_line, 0)
end

---Navigate colors list
---@param direction number 1 for down, -1 for up
local function navigate_colors(direction)
  if not state or not multi_panel then return end

  state.selected_color_idx = state.selected_color_idx + direction

  if state.selected_color_idx < 1 then
    state.selected_color_idx = #Data.COLOR_DEFINITIONS
  elseif state.selected_color_idx > #Data.COLOR_DEFINITIONS then
    state.selected_color_idx = 1
  end

  multi_panel:render_panel("colors")

  -- Position cursor
  local cursor_line = Render.get_color_cursor_line(state, state.selected_color_idx)
  multi_panel:set_cursor("colors", cursor_line, 0)
end

---Edit the currently selected color using the color picker
local function edit_color()
  if not state or not multi_panel then return end

  local color_def = Data.COLOR_DEFINITIONS[state.selected_color_idx]
  if not color_def then return end

  -- Check if we need to create a user copy first
  local theme = state.available_themes[state.selected_theme_idx]
  if theme and not theme.is_user and not theme.is_default then
    -- Auto-create a user copy before editing
    local success = Actions.ensure_user_copy(state, multi_panel)
    if not success then
      return
    end
    -- Reload state after copy was created
    load_theme_colors(state)
  end

  if theme and theme.is_default then
    vim.notify("Cannot edit default theme colors. Select a theme first.", vim.log.levels.WARN)
    return
  end

  -- Get current color value and save original for cancel
  local original_value = vim.deepcopy(state.current_colors[color_def.key] or {})

  -- Working copies of fg/bg colors that we update as user edits
  local working_colors = {
    fg = original_value.fg or "#808080",
    bg = original_value.bg or "#808080",
    bold = original_value.bold or false,
    italic = original_value.italic or false,
  }

  -- Track original colors for each target (for reset/comparison in picker)
  local original_colors = {
    fg = original_value.fg or "#808080",
    bg = original_value.bg or "#808080",
  }

  -- Determine initial target (fg by default, bg if fg is nil but bg exists)
  local initial_target = original_value.fg and "fg" or (original_value.bg and "bg" or "fg")

  -- Helper to apply working colors to theme state
  local function apply_working_colors()
    if not state then return end
    state.current_colors[color_def.key] = {
      fg = working_colors.fg,
      bg = working_colors.bg ~= "#808080" and working_colors.bg or original_value.bg,
      bold = working_colors.bold,
      italic = working_colors.italic,
    }
    state.is_dirty = true
    ThemeManager.apply_colors(state.current_colors)

    if multi_panel then
      local colors_buf = multi_panel:get_panel_buffer("colors")
      if colors_buf then
        Render.apply_swatch_highlights(colors_buf, state)
      end
      multi_panel:render_panel("colors")
      multi_panel:render_panel("preview")
    end
  end

  -- Open color picker with SSNS-specific custom controls
  colorpicker.pick({
    color = working_colors[initial_target],
    title = color_def.name .. " (" .. color_def.key .. ")",

    -- Inject SSNS-specific controls
    custom_controls = {
      {
        id = "target",
        type = "select",
        label = "Target",
        options = { "fg", "bg" },
        default = initial_target,
        key = "B",
        -- When target changes, swap colors
        on_change = function(new_target, old_target)
          -- Save current picker color to the old target
          local current_color = colorpicker.get_color()
          if current_color then
            working_colors[old_target] = current_color
          end
          -- Load the new target's color into the picker (with its original for comparison)
          local new_color = working_colors[new_target]
          local new_original = original_colors[new_target]
          colorpicker.set_color(new_color, new_original)
          -- Apply preview
          apply_working_colors()
        end,
      },
      {
        id = "bold",
        type = "toggle",
        label = "Bold",
        default = working_colors.bold,
        key = "b",
        on_change = function(new_val)
          working_colors.bold = new_val
          apply_working_colors()
        end,
      },
      {
        id = "italic",
        type = "toggle",
        label = "Italic",
        default = working_colors.italic,
        key = "i",
        on_change = function(new_val)
          working_colors.italic = new_val
          apply_working_colors()
        end,
      },
    },

    -- Live preview as user navigates the color grid
    on_change = function(result)
      if not state then return end

      -- Update the current target's color in working_colors
      local target = result.custom and result.custom.target or "fg"
      working_colors[target] = result.color
      
      -- Update bold/italic from result
      if result.custom then
        working_colors.bold = result.custom.bold
        working_colors.italic = result.custom.italic
      end

      apply_working_colors()
    end,

    -- User confirmed selection
    on_select = function(result)
      if not state then return end

      -- Final update: save current picker color to the active target
      local target = result.custom and result.custom.target or "fg"
      working_colors[target] = result.color

      if result.custom then
        working_colors.bold = result.custom.bold
        working_colors.italic = result.custom.italic
      end

      apply_working_colors()

      if multi_panel then
        multi_panel:update_panel_title("colors", get_colors_title(state) .. " *")
      end
    end,

    -- User cancelled - restore original
    on_cancel = function()
      if not state then return end

      -- Restore original color
      state.current_colors[color_def.key] = original_value

      -- Re-apply original colors
      ThemeManager.apply_colors(state.current_colors)
      if multi_panel then
        multi_panel:render_panel("colors")
        multi_panel:render_panel("preview")
      end
    end,
  })
end

-- ============================================================================
-- Theme Actions
-- ============================================================================

---Apply selected theme and close
local function apply_and_close()
  if not state then return end

  local theme = state.available_themes[state.selected_theme_idx]
  if theme then
    ThemeManager.set_theme(theme.name, true)
  end

  -- If dirty, save to user theme
  if state.is_dirty then
    local current = state.available_themes[state.selected_theme_idx]
    if current and current.is_user then
      local theme_data = ThemeManager.get_theme(current.name, true)
      if theme_data then
        ThemeManager.save(current.name, current.display_name, state.current_colors, theme_data.description, theme_data.author)
      end
    end
  end

  ThemeEditor.close()
end

---Cancel and restore original theme
local function cancel()
  if not state then return end

  -- Restore original theme
  ThemeManager.preview(state.original_theme)

  ThemeEditor.close()
end

---Callback after theme action (copy/delete/rename)
local function on_action_complete()
  if not state or not multi_panel then return end

  -- Reload theme colors
  load_theme_colors(state)

  -- Apply preview
  apply_preview()

  -- Re-render
  multi_panel:render_all()
  multi_panel:update_panel_title("colors", get_colors_title(state))
end

-- ============================================================================
-- Public API
-- ============================================================================

---Close the theme editor
function ThemeEditor.close()
  if multi_panel then
    Render.clear_swatch_highlights()
    multi_panel:close()
    multi_panel = nil
  end
  state = nil
end

---Show the theme editor UI
function ThemeEditor.show()
  -- Close existing editor if open
  ThemeEditor.close()

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

  -- Find current theme index
  local current_theme = ThemeManager.get_current()
  local selected_idx = 1
  if current_theme then
    for i, theme in ipairs(themes) do
      if theme.name == current_theme then
        selected_idx = i
        break
      end
    end
  end

  -- Initialize state
  state = {
    available_themes = themes,
    selected_theme_idx = selected_idx,
    selected_color_idx = 1,
    current_colors = {},
    original_theme = current_theme,
    is_dirty = false,
    editing_user_copy = false,
  }

  -- Load initial theme colors
  load_theme_colors(state)

  -- Get keymaps from config
  local km = KeymapManager.get_group("common")

  -- Get initial theme name for title
  local initial_theme = themes[selected_idx]
  local theme_name = initial_theme and initial_theme.display_name or "None"

  -- Create multi-panel window
  multi_panel = UiFloat.create_multi_panel({
    layout = {
      split = "horizontal",
      children = {
        {
          name = "themes",
          title = "Themes",
          ratio = 0.18,
          filetype = "nvim-float",
          on_render = function() return Render.render_themes(state) end,
          on_focus = function()
            if multi_panel and state then
              multi_panel:update_panel_title("themes", "Themes *")
              multi_panel:update_panel_title("colors", get_colors_title(state))
              local cursor_line = Render.get_theme_cursor_line(state, state.selected_theme_idx)
              multi_panel:set_cursor("themes", cursor_line, 0)
            end
          end,
        },
        {
          name = "colors",
          title = string.format("Colors [%s]", theme_name),
          ratio = 0.40,
          filetype = "nvim-float",
          on_render = function() return Render.render_colors(state) end,
          on_create = function(bufnr, winid)
            -- Create a CursorLine highlight that only sets background (no foreground)
            -- This allows the swatch colors to show through
            vim.api.nvim_set_hl(0, "NvimFloatSelectedBgOnly", {
              bg = vim.api.nvim_get_hl(0, { name = "NvimFloatSelected" }).bg or "#3a3a3a",
            })

            -- Set winhighlight to use the bg-only version for CursorLine
            vim.api.nvim_set_option_value(
              'winhighlight',
              'Normal:Normal,FloatBorder:NvimFloatBorder,FloatTitle:NvimFloatTitle,CursorLine:NvimFloatSelectedBgOnly',
              { win = winid }
            )

            -- Apply swatch highlights after buffer is created
            vim.schedule(function()
              Render.apply_swatch_highlights(bufnr, state)
            end)
          end,
          on_focus = function()
            if multi_panel and state then
              multi_panel:update_panel_title("themes", "Themes")
              multi_panel:update_panel_title("colors", get_colors_title(state) .. " *")
              local cursor_line = Render.get_color_cursor_line(state, state.selected_color_idx)
              multi_panel:set_cursor("colors", cursor_line, 0)
            end
          end,
        },
        {
          name = "preview",
          title = "Preview",
          ratio = 0.42,
          filetype = "nvim-float",
          cursorline = false,
          on_render = function() return Render.render_preview(state) end,
          on_create = function(bufnr)
            -- Mark buffer to skip semantic highlighting (we use pre-defined highlights)
            vim.b[bufnr].ssns_skip_semantic_highlight = true
          end,
        },
      },
    },
    total_width_ratio = 0.92,
    total_height_ratio = 0.85,
    initial_focus = "themes",
    augroup_name = "SSNSThemeEditor",
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
        header = "Themes Panel",
        keys = {
          { key = "Enter", desc = "Select theme" },
          { key = "c", desc = "Copy theme" },
          { key = "d", desc = "Delete user theme" },
          { key = "r", desc = "Rename user theme" },
        },
      },
      {
        header = "Colors Panel",
        keys = {
          { key = "Enter", desc = "Open color picker" },
        },
      },
      {
        header = "Actions",
        keys = {
          { key = "a", desc = "Apply and close" },
          { key = "q/Esc", desc = "Cancel" },
        },
      },
    },
    on_close = function()
      Render.clear_swatch_highlights()
      multi_panel = nil
      state = nil
    end,
  })

  if not multi_panel then
    return
  end

  -- Render all panels
  multi_panel:render_all()

  -- Apply initial preview
  apply_preview()

  -- Setup keymaps
  ThemeEditor._setup_keymaps()

  -- Mark initial focus
  multi_panel:update_panel_title("themes", "Themes *")

  -- Position cursor on selected theme
  vim.schedule(function()
    if multi_panel and multi_panel:is_valid() and state then
      local cursor_line = Render.get_theme_cursor_line(state, state.selected_theme_idx)
      multi_panel:set_cursor("themes", cursor_line, 0)
    end
  end)
end

---Setup keymaps for all panels
function ThemeEditor._setup_keymaps()
  if not multi_panel then return end

  local km = KeymapManager.get_group("common")

  -- Themes panel keymaps
  multi_panel:set_panel_keymaps("themes", {
    [km.cancel or "<Esc>"] = cancel,
    [km.close or "q"] = cancel,
    ["a"] = apply_and_close,
    [km.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [km.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
    [km.nav_down or "j"] = function() navigate_themes(1) end,
    [km.nav_up or "k"] = function() navigate_themes(-1) end,
    [km.nav_down_alt or "<Down>"] = function() navigate_themes(1) end,
    [km.nav_up_alt or "<Up>"] = function() navigate_themes(-1) end,
    [km.confirm or "<CR>"] = select_theme,
    -- Theme management
    ["c"] = function() Actions.copy_theme(state, multi_panel, on_action_complete) end,
    ["d"] = function() Actions.delete_theme(state, multi_panel, on_action_complete) end,
    ["r"] = function() Actions.rename_theme(state, multi_panel, on_action_complete) end,
  })

  -- Colors panel keymaps
  multi_panel:set_panel_keymaps("colors", {
    [km.cancel or "<Esc>"] = cancel,
    [km.close or "q"] = cancel,
    ["a"] = apply_and_close,
    [km.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [km.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
    [km.nav_down or "j"] = function() navigate_colors(1) end,
    [km.nav_up or "k"] = function() navigate_colors(-1) end,
    [km.nav_down_alt or "<Down>"] = function() navigate_colors(1) end,
    [km.nav_up_alt or "<Up>"] = function() navigate_colors(-1) end,
    -- Color editing with color picker
    [km.confirm or "<CR>"] = edit_color,
  })

  -- Preview panel keymaps
  multi_panel:set_panel_keymaps("preview", {
    [km.cancel or "<Esc>"] = cancel,
    [km.close or "q"] = cancel,
    ["a"] = apply_and_close,
    [km.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [km.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
  })
end

---Check if editor is open
---@return boolean
function ThemeEditor.is_open()
  return multi_panel ~= nil
end

---Get current state (for color picker integration)
---@return ThemeEditorState?
function ThemeEditor.get_state()
  return state
end

---Get multi-panel window (for color picker integration)
---@return MultiPanelWindow?
function ThemeEditor.get_multi_panel()
  return multi_panel
end

return ThemeEditor
