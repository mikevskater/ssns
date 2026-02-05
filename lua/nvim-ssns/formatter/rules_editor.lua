---@class FormatterRulesEditor
---Interactive formatter rules editor with three-panel layout using UiFloat:
---  Left: Preset list (built-in + user)
---  Middle: Settings for selected preset
---  Right: Live SQL preview
local RulesEditor = {}

local Config = require('nvim-ssns.config')
local KeymapManager = require('nvim-ssns.keymap_manager')
local Presets = require('nvim-ssns.formatter.presets')
local UiFloat = require('nvim-float.window')
local Data = require('nvim-ssns.formatter.rules_editor_data')
local Helpers = require('nvim-ssns.formatter.rules_editor_helpers')
local Render = require('nvim-ssns.formatter.rules_editor_render')
local Actions = require('nvim-ssns.formatter.rules_editor_actions')

---@class RulesEditorState
---@field available_presets FormatterPreset[] All available presets
---@field selected_preset_idx number Currently selected preset index
---@field selected_rule_idx number Currently selected rule index
---@field current_config table Working copy of formatter config
---@field original_config table Original config for cancel/reset
---@field is_dirty boolean Whether config has been modified
---@field rule_definitions RuleDefinition[] All rule definitions
---@field editing_user_copy boolean Whether we auto-created a user copy

---@type MultiPanelState?
local multi_panel = nil

---@type RulesEditorState?
local state = nil

---Close the rules editor
function RulesEditor.close()
  if multi_panel then
    Render.disable_preview_highlights(multi_panel)
    multi_panel:close()
    multi_panel = nil
  end
  state = nil
end

---Show the rules editor UI
function RulesEditor.show()
  -- Close existing editor if open
  RulesEditor.close()

  -- Load all presets
  local available_presets = Presets.list()

  -- Get current formatter config
  local current_config = vim.deepcopy(Config.get_formatter())

  -- Find which preset matches current config (if any)
  local selected_preset_idx = 1
  for i, preset in ipairs(available_presets) do
    local matches = true
    for key, val in pairs(preset.config) do
      if current_config[key] ~= val then
        matches = false
        break
      end
    end
    if matches then
      selected_preset_idx = i
      break
    end
  end

  -- Initialize state
  state = {
    available_presets = available_presets,
    selected_preset_idx = selected_preset_idx,
    selected_rule_idx = 1,
    current_config = current_config,
    original_config = vim.deepcopy(current_config),
    is_dirty = false,
    rule_definitions = Data.RULE_DEFINITIONS,
    editing_user_copy = false,
  }

  -- Get keymaps from config
  local km = KeymapManager.get_group("common")

  -- Build preset title
  local preset = state.available_presets[state.selected_preset_idx]
  local preset_name = preset and preset.name or "None"
  if preset and preset.is_user then
    preset_name = preset_name .. " (user)"
  end

  -- Create multi-panel window using UiFloat nested layout
  multi_panel = UiFloat.create_multi_panel({
    layout = {
      split = "horizontal",
      children = {
        {
          name = "presets",
          title = "Presets",
          ratio = 0.18,
          on_render = function() return Render.render_presets(state) end,
          on_focus = function()
            if multi_panel and state then
              multi_panel:update_panel_title("presets", "Presets ●")
              multi_panel:update_panel_title("rules", Helpers.get_rules_title(state))
              local cursor_line = Helpers.get_preset_cursor_line(state, state.selected_preset_idx)
              multi_panel:set_cursor("presets", cursor_line, 0)
            end
          end,
        },
        {
          name = "rules",
          title = string.format("Settings [%s]", preset_name),
          ratio = 0.35,
          on_render = function() return Render.render_rules(state) end,
          on_focus = function()
            if multi_panel and state then
              multi_panel:update_panel_title("presets", "Presets")
              multi_panel:update_panel_title("rules", Helpers.get_rules_title(state) .. " ●")
              local cursor_line = Helpers.get_rule_cursor_line(state, state.selected_rule_idx)
              multi_panel:set_cursor("rules", cursor_line, 0)
            end
          end,
        },
        {
          name = "preview",
          title = "Preview",
          ratio = 0.47,
          filetype = "sql",
          focusable = true,
          cursorline = false,
          on_render = function() return Render.render_preview(state) end,
        },
      },
    },
    total_width_ratio = 0.90,
    total_height_ratio = 0.70,
    initial_focus = "presets",
    augroup_name = "SSNSFormatterRulesEditor",
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
        header = "Presets Panel",
        keys = {
          { key = "Enter", desc = "Select preset" },
          { key = "d", desc = "Delete user preset" },
          { key = "r", desc = "Rename user preset" },
        },
      },
      {
        header = "Rules Panel",
        keys = {
          { key = "h/l", desc = "Change value" },
          { key = "+/-", desc = "Increment/decrement" },
          { key = "s", desc = "Save as preset" },
          { key = "R", desc = "Reset to defaults" },
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
      Render.disable_preview_highlights(multi_panel)
      multi_panel = nil
      state = nil
    end,
  })

  if not multi_panel then
    return
  end

  -- Render all panels
  multi_panel:render_all()

  -- Apply semantic highlighting to preview
  Render.apply_preview_highlights(multi_panel)

  -- Setup keymaps
  RulesEditor._setup_keymaps()

  -- Mark initial focus
  multi_panel:update_panel_title("presets", "Presets ●")

  -- Position cursor on first preset
  vim.schedule(function()
    if multi_panel and multi_panel:is_valid() and state then
      local cursor_line = Helpers.get_preset_cursor_line(state, state.selected_preset_idx)
      multi_panel:set_cursor("presets", cursor_line, 0)
    end
  end)
end

---Setup keymaps for all panels
function RulesEditor._setup_keymaps()
  if not multi_panel then return end

  local km = KeymapManager.get_group("common")

  -- Presets panel keymaps
  multi_panel:set_panel_keymaps("presets", {
    [km.cancel or "<Esc>"] = function() RulesEditor.close() end,
    [km.close or "q"] = function() RulesEditor.close() end,
    ["a"] = function() Actions.apply(state, RulesEditor.close) end,
    [km.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [km.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
    [km.nav_down or "j"] = function() Actions.navigate_presets(state, multi_panel, 1) end,
    [km.nav_up or "k"] = function() Actions.navigate_presets(state, multi_panel, -1) end,
    [km.nav_down_alt or "<Down>"] = function() Actions.navigate_presets(state, multi_panel, 1) end,
    [km.nav_up_alt or "<Up>"] = function() Actions.navigate_presets(state, multi_panel, -1) end,
    [km.confirm or "<CR>"] = function() Actions.select_preset(state, multi_panel) end,
    ["d"] = function() Actions.delete_preset(state, multi_panel) end,
    ["r"] = function() Actions.rename_preset(state, multi_panel) end,
  })

  -- Rules panel keymaps
  multi_panel:set_panel_keymaps("rules", {
    [km.cancel or "<Esc>"] = function() RulesEditor.close() end,
    [km.close or "q"] = function() RulesEditor.close() end,
    ["a"] = function() Actions.apply(state, RulesEditor.close) end,
    [km.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [km.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
    [km.nav_down or "j"] = function() Actions.navigate_rules(state, multi_panel, 1) end,
    [km.nav_up or "k"] = function() Actions.navigate_rules(state, multi_panel, -1) end,
    [km.nav_down_alt or "<Down>"] = function() Actions.navigate_rules(state, multi_panel, 1) end,
    [km.nav_up_alt or "<Up>"] = function() Actions.navigate_rules(state, multi_panel, -1) end,
    ["l"] = function() Actions.cycle_value(state, multi_panel, 1) end,
    ["h"] = function() Actions.cycle_value(state, multi_panel, -1) end,
    ["+"] = function() Actions.cycle_value(state, multi_panel, 1) end,
    ["-"] = function() Actions.cycle_value(state, multi_panel, -1) end,
    ["<Right>"] = function() Actions.cycle_value(state, multi_panel, 1) end,
    ["<Left>"] = function() Actions.cycle_value(state, multi_panel, -1) end,
    ["s"] = function() Actions.save_preset(state, multi_panel) end,
    ["R"] = function() Actions.reset(state, multi_panel) end,
  })

  -- Preview panel keymaps
  multi_panel:set_panel_keymaps("preview", {
    [km.cancel or "<Esc>"] = function() RulesEditor.close() end,
    [km.close or "q"] = function() RulesEditor.close() end,
    ["a"] = function() Actions.apply(state, RulesEditor.close) end,
    [km.next_field or "<Tab>"] = function() multi_panel:focus_next_panel() end,
    [km.prev_field or "<S-Tab>"] = function() multi_panel:focus_prev_panel() end,
  })
end

---Check if editor is open
---@return boolean
function RulesEditor.is_open()
  return multi_panel ~= nil
end

return RulesEditor
