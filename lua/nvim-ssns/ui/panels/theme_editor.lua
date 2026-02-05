---@class ThemeEditor
---Interactive theme editor with three-panel layout:
---  Left: Theme list (built-in + user)
---  Middle: Color settings for selected theme
---  Right: Live SQL preview
local ThemeEditor = {}

local KeymapManager = require('nvim-ssns.keymap_manager')
local ThemeManager = require('nvim-ssns.ui.theme_manager')
local UiFloat = require('nvim-float.window')
local Data = require('nvim-ssns.ui.panels.theme_editor_data')
local Render = require('nvim-ssns.ui.panels.theme_editor_render')
local Actions = require('nvim-ssns.ui.panels.theme_picker_actions')
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

---Calculate the line number for a theme based on its index
---This matches the rendering order in theme_editor_render.lua
---@param st ThemeEditorState
---@param theme_idx number The index in available_themes
---@return number line_number 1-indexed line number
local function get_theme_line_number(st, theme_idx)
  if not st or not st.available_themes then return 2 end

  -- Separate themes into categories (same logic as render_themes)
  local default_idx = nil
  local user_themes = {}
  local builtin_themes = {}

  for i, theme in ipairs(st.available_themes) do
    if theme.is_default then
      default_idx = i
    elseif theme.is_user then
      table.insert(user_themes, { idx = i })
    else
      table.insert(builtin_themes, { idx = i })
    end
  end

  -- Calculate line number based on rendering order:
  -- Line 1: Blank
  -- Line 2: Default theme
  local line = 2

  -- Check if target is the default theme
  if theme_idx == default_idx then
    return line
  end

  -- After default theme, check user themes section
  if #user_themes > 0 then
    -- Line: blank, "User Themes" header, blank
    line = line + 3

    for _, entry in ipairs(user_themes) do
      if entry.idx == theme_idx then
        return line
      end
      line = line + 1
    end
  end

  -- Built-in section: blank, "Built-in" header, blank
  line = line + 3

  for _, entry in ipairs(builtin_themes) do
    if entry.idx == theme_idx then
      return line
    end
    line = line + 1
  end

  -- Fallback
  return 2
end

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

---Get the color element at cursor position
---@return table? element_data { def, index } or nil if not on a color
local function get_color_at_cursor()
  if not multi_panel then return nil end
  local element = multi_panel:get_element_at_cursor()
  if element and element.type == "color" then
    return element.data
  end
  return nil
end

---Get the theme element at cursor position
---@return table? element_data { theme, index } or nil if not on a theme
local function get_theme_at_cursor()
  if not multi_panel then return nil end
  local element = multi_panel:get_element_at_cursor()
  if element and element.type == "theme" then
    return element.data
  end
  return nil
end

---Select theme at cursor and move to colors panel
local function select_theme()
  if not state or not multi_panel then return end

  -- Get theme from cursor position
  local element = get_theme_at_cursor()
  if not element then return end -- Not on a theme element

  -- Update state with selection
  state.selected_theme_idx = element.index
  state.is_dirty = false
  state.editing_user_copy = false

  -- Load theme colors and apply preview
  load_theme_colors(state)
  apply_preview()

  -- Re-render all panels (themes panel needs to update selection arrow)
  multi_panel:render_panel("themes")
  multi_panel:render_panel("colors")
  multi_panel:render_panel("preview")
  multi_panel:update_panel_title("colors", get_colors_title(state))
  multi_panel:focus_panel("colors")
end

---Edit the currently selected color using the color picker
local function edit_color()
  if not state or not multi_panel then return end

  -- Get color definition from element at cursor
  local element_data = get_color_at_cursor()
  if not element_data then return end

  local color_def = element_data.def
  if not color_def then return end

  -- Update state to match cursor
  state.selected_color_idx = element_data.index

  -- Check if we need to create a user copy first
  local theme = state.available_themes[state.selected_theme_idx]
  if theme and not theme.is_user then
    -- Auto-create a user copy before editing
    local success = Actions.ensure_user_copy(state, multi_panel)
    if not success then
      return
    end
    -- Reload state after copy was created
    load_theme_colors(state)
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
        end,
      },
    },

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
        local ok, err = ThemeManager.save(current.name, current.display_name, state.current_colors, theme_data.description, theme_data.author)
        if ok then
          vim.notify("Theme saved: " .. current.display_name, vim.log.levels.INFO)
        else
          vim.notify("Failed to save theme: " .. (err or "unknown error"), vim.log.levels.ERROR)
        end
      end
    end
  end

  ThemeEditor.close()
end

---Cancel and restore original theme
local function cancel()
  if not state then
    -- State was already cleared, just ensure cleanup
    if multi_panel then
      multi_panel:close()
      multi_panel = nil
    end
    return
  end

  -- Capture state values before any dialog (in case state gets modified)
  local is_dirty = state.is_dirty
  local original_theme = state.original_theme
  local current_theme_info = state.available_themes[state.selected_theme_idx]
  local theme_name = current_theme_info and current_theme_info.display_name or "theme"

  -- Check for unsaved changes
  if is_dirty then
    -- Show confirmation dialog
    local confirm_win = UiFloat.create({
      title = "Unsaved Changes",
      width = 50,
      height = 7,
      center = true,
      content_builder = true,
      zindex = UiFloat.ZINDEX.MODAL,
    })

    if confirm_win then
      local cb = confirm_win:get_content_builder()
      cb:line("")
      cb:styled("  You have unsaved changes to '" .. theme_name .. "'.", "NvimFloatTitle")
      cb:line("")
      cb:styled("  Discard changes and close?", "NvimFloatLabel")
      cb:line("")
      cb:styled("  <Enter>=Discard | <a>=Apply & Close | <Esc>=Cancel", "NvimFloatHint")
      confirm_win:render()

      -- Discard changes and close (use captured original_theme)
      vim.keymap.set("n", "<CR>", function()
        confirm_win:close()
        ThemeManager.preview(original_theme)
        ThemeEditor.close()
      end, { buffer = confirm_win.buf, nowait = true })

      -- Apply changes and close
      vim.keymap.set("n", "a", function()
        confirm_win:close()
        apply_and_close()
      end, { buffer = confirm_win.buf, nowait = true })

      -- Cancel (go back to editor)
      vim.keymap.set("n", "<Esc>", function()
        confirm_win:close()
      end, { buffer = confirm_win.buf, nowait = true })

      vim.keymap.set("n", "q", function()
        confirm_win:close()
      end, { buffer = confirm_win.buf, nowait = true })

      return
    end
  end

  -- No unsaved changes, just close (use captured original_theme)
  ThemeManager.preview(original_theme)
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
          on_render = function()
            local lines, highlights, cb = Render.render_themes(state)
            -- Associate ContentBuilder with panel for element tracking (if supported)
            if multi_panel and cb and multi_panel.set_panel_content_builder then
              multi_panel:set_panel_content_builder("themes", cb)
            end
            return lines, highlights
          end,
          on_focus = function()
            if multi_panel and state then
              multi_panel:update_panel_title("themes", "Themes *")
              multi_panel:update_panel_title("colors", get_colors_title(state))
              -- Cursor position is preserved, no need to manually set
            end
          end,
        },
        {
          name = "colors",
          title = string.format("Colors [%s]", theme_name),
          ratio = 0.40,
          filetype = "nvim-float",
          on_render = function()
            local lines, highlights, cb = Render.render_colors(state)
            -- Associate ContentBuilder with panel for element tracking (if supported)
            if multi_panel and cb and multi_panel.set_panel_content_builder then
              multi_panel:set_panel_content_builder("colors", cb)
            end
            return lines, highlights
          end,
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
              -- Cursor position is preserved, no need to manually set
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
          { key = "j/k", desc = "Move cursor" },
          { key = "Tab", desc = "Next panel" },
          { key = "S-Tab", desc = "Previous panel" },
        },
      },
      {
        header = "Themes",
        keys = {
          { key = "Enter", desc = "Select theme" },
          { key = "c", desc = "Copy" },
          { key = "d", desc = "Delete" },
          { key = "r", desc = "Rename" },
        },
      },
      {
        header = "Colors",
        keys = {
          { key = "Enter", desc = "Edit color" },
        },
      },
      {
        header = "Actions",
        keys = {
          { key = "a", desc = "Apply & close" },
          { key = "q/Esc", desc = "Cancel" },
        },
      },
    },
    on_close = function()
      Render.clear_swatch_highlights()
      -- Note: Don't nil out state here - let cancel() handle confirmation first
      -- The actual cleanup happens in ThemeEditor.close()
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

  -- Position cursor on the currently selected theme
  vim.schedule(function()
    if multi_panel and multi_panel:is_valid() and state then
      local line = get_theme_line_number(state, state.selected_theme_idx)
      multi_panel:set_cursor("themes", line, 0)
    end
  end)
end

---Setup keymaps for all panels
function ThemeEditor._setup_keymaps()
  if not multi_panel then return end

  local km = KeymapManager.get_group("common")

  -- Themes panel keymaps (navigation uses default vim movement)
  multi_panel:set_panel_keymaps("themes", {
    [km.cancel or "<Esc>"] = cancel,
    [km.close or "q"] = cancel,
    ["a"] = apply_and_close,
    [km.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [km.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
    [km.confirm or "<CR>"] = select_theme,
    -- Theme management
    ["c"] = function() Actions.copy_theme(state, multi_panel, on_action_complete) end,
    ["d"] = function() Actions.delete_theme(state, multi_panel, on_action_complete) end,
    ["r"] = function() Actions.rename_theme(state, multi_panel, on_action_complete) end,
  })

  -- Colors panel keymaps (navigation uses default vim movement)
  multi_panel:set_panel_keymaps("colors", {
    [km.cancel or "<Esc>"] = cancel,
    [km.close or "q"] = cancel,
    ["a"] = apply_and_close,
    [km.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [km.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
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
