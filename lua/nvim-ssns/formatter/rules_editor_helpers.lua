---@class FormatterRulesEditorHelpers
---Helper functions for the formatter rules editor
local M = {}

---Get value from config by key path
---@param config table
---@param key string
---@return any
function M.get_config_value(config, key)
  local parts = vim.split(key, ".", { plain = true })
  local current = config
  for _, part in ipairs(parts) do
    if type(current) ~= "table" then return nil end
    current = current[part]
  end
  return current
end

---Set value in config by key path
---@param config table
---@param key string
---@param value any
function M.set_config_value(config, key, value)
  local parts = vim.split(key, ".", { plain = true })
  local current = config
  for i = 1, #parts - 1 do
    if current[parts[i]] == nil then
      current[parts[i]] = {}
    end
    current = current[parts[i]]
  end
  current[parts[#parts]] = value
end

---Cycle value forward
---@param rule RuleDefinition
---@param current_value any
---@return any
function M.cycle_forward(rule, current_value)
  if rule.type == "boolean" then
    return not current_value
  elseif rule.type == "enum" then
    local options = rule.options
    local current_idx = 1
    for i, opt in ipairs(options) do
      if opt == current_value then
        current_idx = i
        break
      end
    end
    return options[current_idx % #options + 1]
  elseif rule.type == "number" then
    local step = rule.step or 1
    local new_val = (current_value or 0) + step
    if rule.max and new_val > rule.max then
      new_val = rule.min or 0
    end
    return new_val
  end
  return current_value
end

---Cycle value backward
---@param rule RuleDefinition
---@param current_value any
---@return any
function M.cycle_backward(rule, current_value)
  if rule.type == "boolean" then
    return not current_value
  elseif rule.type == "enum" then
    local options = rule.options
    local current_idx = 1
    for i, opt in ipairs(options) do
      if opt == current_value then
        current_idx = i
        break
      end
    end
    local prev_idx = current_idx - 1
    if prev_idx < 1 then prev_idx = #options end
    return options[prev_idx]
  elseif rule.type == "number" then
    local step = rule.step or 1
    local new_val = (current_value or 0) - step
    if rule.min and new_val < rule.min then
      new_val = rule.max or 999
    end
    return new_val
  end
  return current_value
end

---Format value for display
---@param rule RuleDefinition
---@param value any
---@return string
function M.format_value(rule, value)
  if value == nil then
    return "nil"
  elseif rule.type == "boolean" then
    return value and "true" or "false"
  elseif rule.type == "number" then
    return tostring(value)
  else
    return tostring(value)
  end
end

---Calculate cursor line for preset index
---@param state RulesEditorState
---@param preset_idx number The preset index
---@return number line The cursor line (1-indexed)
function M.get_preset_cursor_line(state, preset_idx)
  if not state then return 1 end

  -- Start after header (line 1 is empty)
  local line = 2  -- "─── Built-in ───" header
  line = line + 1  -- Empty line after header
  line = line + 1  -- First preset starts here

  -- Count lines to reach the selected preset
  local builtin_added = false
  local user_added = false

  for i, preset in ipairs(state.available_presets) do
    -- Account for section headers
    if not preset.is_user and not builtin_added then
      builtin_added = true
      -- Already counted above for first preset
    elseif preset.is_user and not user_added then
      if builtin_added then
        line = line + 1  -- Empty line between sections
      end
      line = line + 1  -- "─── User ───" header
      line = line + 1  -- Empty line after header
      user_added = true
    end

    if i == preset_idx then
      return line
    end
    line = line + 1
  end

  return line
end

---Calculate cursor line for rule index
---@param state RulesEditorState
---@param rule_idx number The rule index
---@return number line The cursor line (1-indexed)
function M.get_rule_cursor_line(state, rule_idx)
  if not state then return 1 end

  -- Start after header (line 1 is empty)
  local line = 2  -- First category header
  line = line + 1  -- Empty line after header
  line = line + 1  -- First rule starts here

  local current_category = nil

  for i, rule in ipairs(state.rule_definitions) do
    -- Account for category headers
    if rule.category ~= current_category then
      if current_category ~= nil then
        line = line + 1  -- Empty line before category
        line = line + 1  -- Category header
        line = line + 1  -- Empty line after header
      end
      current_category = rule.category
    end

    if i == rule_idx then
      return line
    end
    line = line + 1
  end

  return line
end

---Get dynamic title for rules panel
---@param state RulesEditorState
---@return string
function M.get_rules_title(state)
  if not state then return "Settings" end
  local preset = state.available_presets[state.selected_preset_idx]
  local preset_name = preset and preset.name or "Custom"
  if preset and preset.is_user then
    preset_name = preset_name .. " (user)"
  end
  local dirty_indicator = state.is_dirty and " *" or ""
  return string.format("Settings [%s]%s", preset_name, dirty_indicator)
end

return M
