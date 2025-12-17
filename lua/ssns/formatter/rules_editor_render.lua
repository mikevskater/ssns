---@class FormatterRulesEditorRender
---Rendering functions for the formatter rules editor
---Uses ContentBuilder for themed UI in presets and rules panels
local M = {}

local Helpers = require('ssns.formatter.rules_editor_helpers')
local Formatter = require('ssns.formatter')
local Data = require('ssns.formatter.rules_editor_data')
local ContentBuilder = require('ssns.ui.core.content_builder')

---Render the presets panel using ContentBuilder
---@param state RulesEditorState
---@return string[] lines, table[] highlights
function M.render_presets(state)
  local cb = ContentBuilder.new()

  if not state then
    return cb:build_lines(), cb:build_highlights()
  end

  cb:blank()

  local builtin_added = false
  local user_added = false

  for i, preset in ipairs(state.available_presets) do
    -- Add section headers
    if not preset.is_user and not builtin_added then
      cb:styled(" ─── Built-in ───", "muted")
      cb:blank()
      builtin_added = true
    elseif preset.is_user and not user_added then
      if builtin_added then
        cb:blank()
      end
      cb:styled(" ─── User ───", "muted")
      cb:blank()
      user_added = true
    end

    local is_selected = (i == state.selected_preset_idx)
    local prefix = is_selected and " ▸ " or "   "

    if is_selected then
      -- Selected preset - highlight entire line
      cb:spans({
        { text = prefix, style = "emphasis" },
        { text = preset.name, style = "highlight" },
      })
    else
      cb:spans({
        { text = prefix, style = "muted" },
        { text = preset.name, style = "normal" },
      })
    end
  end

  cb:blank()

  return cb:build_lines(), cb:build_highlights()
end

---Render the rules panel using ContentBuilder
---@param state RulesEditorState
---@return string[] lines, table[] highlights
function M.render_rules(state)
  local cb = ContentBuilder.new()

  if not state then
    return cb:build_lines(), cb:build_highlights()
  end

  cb:blank()

  local current_category = nil

  for i, rule in ipairs(state.rule_definitions) do
    -- Add category header if new category
    if rule.category ~= current_category then
      if current_category ~= nil then
        cb:blank()
      end
      cb:styled(string.format(" ─── %s ───", rule.category), "section")
      cb:blank()
      current_category = rule.category
    end

    local value = Helpers.get_config_value(state.current_config, rule.key)
    local display_value = Helpers.format_value(rule, value)
    local is_selected = (i == state.selected_rule_idx)

    -- Format: "  ▸ Rule Name          [value]" or "    Rule Name          [value]"
    local prefix = is_selected and " ▸ " or "   "
    local name_width = 22
    local padded_name = rule.name .. string.rep(" ", math.max(0, name_width - #rule.name))

    if is_selected then
      cb:spans({
        { text = prefix, style = "emphasis" },
        { text = padded_name, style = "highlight" },
        { text = "[", style = "muted" },
        { text = display_value, style = "string" },
        { text = "]", style = "muted" },
      })
    else
      -- Style value based on type
      local value_style = "number"
      if rule.type == "boolean" then
        value_style = value and "success" or "error"
      elseif rule.type == "enum" then
        value_style = "keyword"
      end

      cb:spans({
        { text = prefix, style = "muted" },
        { text = padded_name, style = "label" },
        { text = "[", style = "muted" },
        { text = display_value, style = value_style },
        { text = "]", style = "muted" },
      })
    end
  end

  cb:blank()

  return cb:build_lines(), cb:build_highlights()
end

---Render the preview panel (raw SQL buffer - no ContentBuilder)
---Returns plain lines for the buffer, semantic highlighting applied separately
---@param state RulesEditorState
---@return string[] lines, table[] highlights (empty - semantic highlighter handles it)
function M.render_preview(state)
  if not state then
    return {}, {}
  end

  -- Format the preview SQL with current config
  local formatted = Formatter.format(Data.PREVIEW_SQL, state.current_config)
  local lines = vim.split(formatted, '\n')

  -- Return empty highlights - semantic highlighter will handle SQL highlighting
  return lines, {}
end

---Apply semantic highlighting to preview buffer
---@param multi_panel MultiPanelState
function M.apply_preview_highlights(multi_panel)
  if not multi_panel then return end
  local preview_buf = multi_panel:get_panel_buffer("preview")
  if not preview_buf then return end

  local ok, SemanticHighlighter = pcall(require, 'ssns.highlighting.semantic')
  if ok and SemanticHighlighter.enable then
    pcall(SemanticHighlighter.enable, preview_buf)
    vim.defer_fn(function()
      if multi_panel and preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
        pcall(SemanticHighlighter.update, preview_buf)
      end
    end, 50)
  end
end

---Disable semantic highlighting on preview
---@param multi_panel MultiPanelState
function M.disable_preview_highlights(multi_panel)
  local ok, SemanticHighlighter = pcall(require, 'ssns.highlighting.semantic')
  if ok and SemanticHighlighter.disable and multi_panel then
    local preview_buf = multi_panel:get_panel_buffer("preview")
    if preview_buf then
      pcall(SemanticHighlighter.disable, preview_buf)
    end
  end
end

return M
