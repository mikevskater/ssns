---@class FormatterRulesEditorActions
---Action handlers for the formatter rules editor
local M = {}

local Config = require('nvim-ssns.config')
local Presets = require('nvim-ssns.formatter.presets')
local Helpers = require('nvim-ssns.formatter.rules_editor_helpers')
local Render = require('nvim-ssns.formatter.rules_editor_render')

---Navigate through presets
---@param state RulesEditorState
---@param multi_panel MultiPanelState
---@param direction number 1 for down, -1 for up
function M.navigate_presets(state, multi_panel, direction)
  if not state or not multi_panel then return end

  state.selected_preset_idx = state.selected_preset_idx + direction

  if state.selected_preset_idx < 1 then
    state.selected_preset_idx = #state.available_presets
  elseif state.selected_preset_idx > #state.available_presets then
    state.selected_preset_idx = 1
  end

  -- Load the preset config
  local preset = state.available_presets[state.selected_preset_idx]
  if preset then
    state.current_config = vim.tbl_deep_extend("force", Config.get_formatter(), preset.config)
    state.is_dirty = false
    state.editing_user_copy = false
  end

  multi_panel:render_all()
  multi_panel:update_panel_title("rules", Helpers.get_rules_title(state))

  -- Position cursor on selected preset
  local cursor_line = Helpers.get_preset_cursor_line(state, state.selected_preset_idx)
  multi_panel:set_cursor("presets", cursor_line, 0)

  -- Apply semantic highlighting to preview
  Render.apply_preview_highlights(multi_panel)
end

---Select current preset (same as navigate but explicit)
---@param state RulesEditorState
---@param multi_panel MultiPanelState
function M.select_preset(state, multi_panel)
  if not state or not multi_panel then return end

  local preset = state.available_presets[state.selected_preset_idx]
  if preset then
    state.current_config = vim.tbl_deep_extend("force", Config.get_formatter(), preset.config)
    state.is_dirty = false
    state.editing_user_copy = false

    multi_panel:render_panel("rules")
    multi_panel:render_panel("preview")
    multi_panel:update_panel_title("rules", Helpers.get_rules_title(state))

    -- Apply semantic highlighting to preview
    Render.apply_preview_highlights(multi_panel)

    -- Move to rules panel and position cursor
    multi_panel:focus_panel("rules")
    local cursor_line = Helpers.get_rule_cursor_line(state, state.selected_rule_idx)
    multi_panel:set_cursor("rules", cursor_line, 0)
  end
end

---Navigate through rules
---@param state RulesEditorState
---@param multi_panel MultiPanelState
---@param direction number 1 for down, -1 for up
function M.navigate_rules(state, multi_panel, direction)
  if not state or not multi_panel then return end

  state.selected_rule_idx = state.selected_rule_idx + direction

  if state.selected_rule_idx < 1 then
    state.selected_rule_idx = #state.rule_definitions
  elseif state.selected_rule_idx > #state.rule_definitions then
    state.selected_rule_idx = 1
  end

  multi_panel:render_panel("rules")

  -- Position cursor on selected rule
  local cursor_line = Helpers.get_rule_cursor_line(state, state.selected_rule_idx)
  multi_panel:set_cursor("rules", cursor_line, 0)
end

---Cycle the value of current rule
---@param state RulesEditorState
---@param multi_panel MultiPanelState
---@param direction number 1 for forward, -1 for backward
function M.cycle_value(state, multi_panel, direction)
  if not state or not multi_panel then return end

  -- Check if we need to create a user copy first
  local preset = state.available_presets[state.selected_preset_idx]
  if preset and not preset.is_user and not state.editing_user_copy then
    -- Auto-create a user copy
    local copy_name = preset.name .. " - COPY"
    local file_name = (preset.file_name or preset.name:lower():gsub("%s+", "_")) .. "_copy"
    file_name = Presets.generate_unique_name(file_name, true)

    local ok, err = Presets.save(file_name, copy_name, state.current_config, "Auto-created copy of " .. preset.name)
    if ok then
      -- Reload presets and select the new copy
      Presets.clear_cache()
      state.available_presets = Presets.list()

      -- Find the new copy
      for i, p in ipairs(state.available_presets) do
        if p.name == copy_name or p.file_name == file_name then
          state.selected_preset_idx = i
          break
        end
      end

      state.editing_user_copy = true
      vim.notify("Created user copy: " .. copy_name, vim.log.levels.INFO)
      multi_panel:render_panel("presets")
    else
      vim.notify("Failed to create copy: " .. (err or "unknown"), vim.log.levels.ERROR)
      return
    end
  end

  local rule = state.rule_definitions[state.selected_rule_idx]
  if not rule then return end

  local current_value = Helpers.get_config_value(state.current_config, rule.key)
  local new_value

  if direction > 0 then
    new_value = Helpers.cycle_forward(rule, current_value)
  else
    new_value = Helpers.cycle_backward(rule, current_value)
  end

  Helpers.set_config_value(state.current_config, rule.key, new_value)
  state.is_dirty = true

  multi_panel:render_panel("rules")
  multi_panel:update_panel_title("rules", Helpers.get_rules_title(state) .. " ●")

  -- Debounced preview update
  vim.defer_fn(function()
    if multi_panel and state then
      multi_panel:render_panel("preview")
      Render.apply_preview_highlights(multi_panel)
    end
  end, 50)
end

---Apply changes
---@param state RulesEditorState
---@param close_fn function Function to close the editor
function M.apply(state, close_fn)
  if not state then return end

  Config.current.formatter = state.current_config

  -- If dirty, save to preset if it's a user preset
  if state.is_dirty then
    local preset = state.available_presets[state.selected_preset_idx]
    if preset and preset.is_user then
      Presets.save(preset.file_name, preset.name, state.current_config, preset.description)
    end
  end

  vim.notify("Formatter config applied", vim.log.levels.INFO)
  close_fn()
end

---Reset current preset to its original values
---@param state RulesEditorState
---@param multi_panel MultiPanelState
function M.reset(state, multi_panel)
  if not state or not multi_panel then return end

  local preset = state.available_presets[state.selected_preset_idx]
  if preset then
    -- Reload preset from disk
    Presets.clear_cache()
    local fresh_preset = Presets.load(preset.file_name or preset.name)
    if fresh_preset then
      state.current_config = vim.tbl_deep_extend("force", Config.get_formatter(), fresh_preset.config)
      state.is_dirty = false

      multi_panel:render_panel("rules")
      multi_panel:render_panel("preview")
      multi_panel:update_panel_title("rules", Helpers.get_rules_title(state))
      Render.apply_preview_highlights(multi_panel)

      vim.notify("Reset to preset defaults", vim.log.levels.INFO)
    end
  end
end

---Save current config as a new preset
---@param state RulesEditorState
---@param multi_panel MultiPanelState
function M.save_preset(state, multi_panel)
  if not state or not multi_panel then return end

  local UiFloat = require('nvim-float.window')

  local current_preset = state.available_presets[state.selected_preset_idx]
  local default_name = current_preset and current_preset.is_user and current_preset.name or Presets.generate_unique_name("Custom")

  local save_win = UiFloat.create({
    title = "Save Preset",
    width = 55,
    height = 8,
    center = true,
    content_builder = true,
    enable_inputs = true,
    zindex = UiFloat.ZINDEX.MODAL,
  })

  if save_win then
    local cb = save_win:get_content_builder()
    cb:line("")
    cb:styled("  Save current settings as preset:", "NvimFloatTitle")
    cb:line("")
    cb:labeled_input("name", "  Name", {
      value = default_name,
      placeholder = "(enter preset name)",
      width = 35,
    })
    cb:line("")
    cb:styled("  <Enter>=Save | <Esc>=Cancel", "NvimFloatHint")
    save_win:render()

    local function do_save()
      local name = save_win:get_input_value("name")
      save_win:close()

      if not name or name == "" then return end

      local file_name = name:gsub("[^%w_%-]", "_")
      local ok, err = Presets.save(file_name, name, state.current_config, "User-defined preset")

      if ok then
        -- Reload presets
        Presets.clear_cache()
        state.available_presets = Presets.list()

        -- Find and select the new preset
        for i, p in ipairs(state.available_presets) do
          if p.name == name then
            state.selected_preset_idx = i
            break
          end
        end

        state.is_dirty = false
        if multi_panel then
          multi_panel:render_panel("presets")
          multi_panel:update_panel_title("rules", Helpers.get_rules_title(state))
        end

        vim.notify("Preset saved: " .. name, vim.log.levels.INFO)
      else
        vim.notify("Failed to save: " .. (err or "unknown"), vim.log.levels.ERROR)
      end
    end

    vim.keymap.set("n", "<CR>", function()
      save_win:enter_input()
    end, { buffer = save_win.buf, nowait = true })

    vim.keymap.set("n", "<Esc>", function()
      save_win:close()
    end, { buffer = save_win.buf, nowait = true })

    vim.keymap.set("n", "q", function()
      save_win:close()
    end, { buffer = save_win.buf, nowait = true })

    save_win:on_input_submit(do_save)
  end
end

---Delete selected preset (user only)
---@param state RulesEditorState
---@param multi_panel MultiPanelState
function M.delete_preset(state, multi_panel)
  if not state or not multi_panel then return end

  local preset = state.available_presets[state.selected_preset_idx]
  if not preset or not preset.is_user then
    vim.notify("Can only delete user presets", vim.log.levels.WARN)
    return
  end

  vim.ui.select({ "Yes", "No" }, {
    prompt = string.format("Delete '%s'?", preset.name),
  }, function(choice)
    if choice ~= "Yes" then return end

    local ok, err = Presets.delete(preset.file_name)
    if ok then
      Presets.clear_cache()
      state.available_presets = Presets.list()
      state.selected_preset_idx = math.min(state.selected_preset_idx, #state.available_presets)

      -- Load the now-selected preset
      local new_preset = state.available_presets[state.selected_preset_idx]
      if new_preset then
        state.current_config = vim.tbl_deep_extend("force", Config.get_formatter(), new_preset.config)
      end

      state.is_dirty = false
      if multi_panel then
        multi_panel:render_all()
        multi_panel:update_panel_title("rules", Helpers.get_rules_title(state))
        Render.apply_preview_highlights(multi_panel)
      end

      vim.notify("Preset deleted", vim.log.levels.INFO)
    else
      vim.notify("Failed to delete: " .. (err or "unknown"), vim.log.levels.ERROR)
    end
  end)
end

---Rename selected preset (user only)
---@param state RulesEditorState
---@param multi_panel MultiPanelState
function M.rename_preset(state, multi_panel)
  if not state or not multi_panel then return end

  local UiFloat = require('nvim-float.window')

  local preset = state.available_presets[state.selected_preset_idx]
  if not preset or not preset.is_user then
    vim.notify("Can only rename user presets", vim.log.levels.WARN)
    return
  end

  local rename_win = UiFloat.create({
    title = "Rename Preset",
    width = 55,
    height = 8,
    center = true,
    content_builder = true,
    enable_inputs = true,
    zindex = UiFloat.ZINDEX.MODAL,
  })

  if rename_win then
    local cb = rename_win:get_content_builder()
    cb:line("")
    cb:line(string.format("  Rename preset '%s':", preset.name), "NvimFloatTitle")
    cb:line("")
    cb:labeled_input("name", "  New name", {
      value = preset.name,
      placeholder = "(enter new name)",
      width = 32,
    })
    cb:line("")
    cb:styled("  <Enter>=Rename | <Esc>=Cancel", "NvimFloatHint")
    rename_win:render()

    local function do_rename()
      local new_name = rename_win:get_input_value("name")
      rename_win:close()

      if not new_name or new_name == "" then return end

      local ok, err = Presets.rename(preset.file_name, new_name)
      if ok then
        Presets.clear_cache()
        state.available_presets = Presets.list()

        -- Find the renamed preset
        for i, p in ipairs(state.available_presets) do
          if p.name == new_name then
            state.selected_preset_idx = i
            break
          end
        end

        if multi_panel then
          multi_panel:render_panel("presets")
          multi_panel:update_panel_title("rules", Helpers.get_rules_title(state))
        end

        vim.notify("Preset renamed", vim.log.levels.INFO)
      else
        vim.notify("Failed to rename: " .. (err or "unknown"), vim.log.levels.ERROR)
      end
    end

    vim.keymap.set("n", "<CR>", function()
      rename_win:enter_input()
    end, { buffer = rename_win.buf, nowait = true })

    vim.keymap.set("n", "<Esc>", function()
      rename_win:close()
    end, { buffer = rename_win.buf, nowait = true })

    vim.keymap.set("n", "q", function()
      rename_win:close()
    end, { buffer = rename_win.buf, nowait = true })

    rename_win:on_input_submit(do_rename)
  end
end

return M
