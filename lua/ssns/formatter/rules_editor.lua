---@class FormatterRulesEditor
---Interactive formatter rules editor with live preview
local RulesEditor = {}

local Config = require('ssns.config')
local KeymapManager = require('ssns.keymap_manager')
local Presets = require('ssns.formatter.presets')
local Formatter = require('ssns.formatter')

---@class RuleDefinition
---@field key string Config key path
---@field name string Display name
---@field description string Rule description
---@field type string "boolean"|"number"|"enum"
---@field options? string[] For enum type, valid options
---@field min? number For number type, minimum value
---@field max? number For number type, maximum value
---@field step? number For number type, increment step
---@field category string Category for grouping

---@class RulesEditorState
---@field rules_buf number Rules list buffer
---@field rules_win number Rules list window
---@field preview_buf number Preview buffer
---@field preview_win number Preview window
---@field footer_buf number Footer buffer
---@field footer_win number Footer window
---@field selected_idx number Currently selected rule index
---@field current_config table Working copy of formatter config
---@field original_config table Original config for cancel/reset
---@field current_preset string? Current preset name
---@field original_preset string? Original preset when opened
---@field is_dirty boolean Whether config has been modified
---@field focused_panel string Which panel is focused
---@field rule_definitions RuleDefinition[] All rule definitions
---@field rule_line_map table<number, number> Rule index to line number map
---@field line_to_rule table<number, number> Line number to rule index map

---@type RulesEditorState?
local state = nil

-- Rule definitions organized by category
local RULE_DEFINITIONS = {
  -- General
  { key = "enabled", name = "Enabled", description = "Enable/disable formatter globally", type = "boolean", category = "General" },
  { key = "keyword_case", name = "Keyword Case", description = "Transform keyword casing", type = "enum", options = {"upper", "lower", "preserve"}, category = "General" },
  { key = "max_line_length", name = "Max Line Length", description = "Soft limit for line wrapping (0=disable)", type = "number", min = 0, max = 500, step = 10, category = "General" },
  { key = "preserve_comments", name = "Preserve Comments", description = "Keep comments in formatted output", type = "boolean", category = "General" },
  { key = "format_on_save", name = "Format on Save", description = "Auto-format when saving SQL buffers", type = "boolean", category = "General" },

  -- Indentation
  { key = "indent_size", name = "Indent Size", description = "Spaces per indent level", type = "number", min = 1, max = 8, step = 1, category = "Indentation" },
  { key = "indent_style", name = "Indent Style", description = "Use spaces or tabs for indentation", type = "enum", options = {"space", "tab"}, category = "Indentation" },
  { key = "subquery_indent", name = "Subquery Indent", description = "Extra indent levels for subqueries", type = "number", min = 0, max = 4, step = 1, category = "Indentation" },
  { key = "case_indent", name = "CASE Indent", description = "Indent levels for CASE/WHEN blocks", type = "number", min = 0, max = 4, step = 1, category = "Indentation" },

  -- Clauses
  { key = "newline_before_clause", name = "Newline Before Clause", description = "Start major clauses on new lines", type = "boolean", category = "Clauses" },
  { key = "comma_position", name = "Comma Position", description = "Place commas at start or end of line", type = "enum", options = {"trailing", "leading"}, category = "Clauses" },
  { key = "and_or_position", name = "AND/OR Position", description = "Place AND/OR at start or end of line", type = "enum", options = {"leading", "trailing"}, category = "Clauses" },

  -- Joins
  { key = "join_on_same_line", name = "JOIN ON Same Line", description = "Keep ON clause on same line as JOIN", type = "boolean", category = "Joins" },

  -- Alignment
  { key = "align_aliases", name = "Align Aliases", description = "Vertically align AS keywords in SELECT", type = "boolean", category = "Alignment" },
  { key = "align_columns", name = "Align Columns", description = "Vertically align column expressions", type = "boolean", category = "Alignment" },

  -- Spacing
  { key = "operator_spacing", name = "Operator Spacing", description = "Add spaces around operators (=, +, etc.)", type = "boolean", category = "Spacing" },
  { key = "parenthesis_spacing", name = "Parenthesis Spacing", description = "Add spaces inside parentheses", type = "boolean", category = "Spacing" },
}

-- Get categories in display order
local CATEGORIES = { "General", "Indentation", "Clauses", "Joins", "Alignment", "Spacing" }

-- Sample SQL for live preview
local PREVIEW_SQL = [[
-- Formatter Preview
WITH ActiveUsers AS (
    SELECT id, username, email, status
    FROM dbo.Users
    WHERE status = 'active'
        AND created_at > '2024-01-01'
)
SELECT
    u.id,
    u.username,
    u.email,
    COUNT(o.id) AS order_count,
    SUM(o.amount) AS total_spent,
    CASE
        WHEN SUM(o.amount) > 1000 THEN 'VIP'
        WHEN SUM(o.amount) > 500 THEN 'Regular'
        ELSE 'New'
    END AS customer_tier
FROM ActiveUsers u
LEFT JOIN dbo.Orders o ON u.id = o.user_id
    AND o.status = 'completed'
INNER JOIN dbo.Profiles p ON u.id = p.user_id
WHERE u.email LIKE '%@company.com'
    AND (o.amount > 100 OR o.is_priority = 1)
    AND u.id IN (
        SELECT user_id
        FROM dbo.Subscriptions
        WHERE plan = 'premium'
    )
GROUP BY u.id, u.username, u.email
HAVING COUNT(o.id) > 0
ORDER BY total_spent DESC, u.username ASC;
]]

-- ============================================================================
-- Internal Helpers
-- ============================================================================

---Create custom borders for unified appearance
---@return table borders
local function create_borders()
  local chars = {
    horizontal = "─",
    vertical = "│",
    top_left = "╭",
    top_right = "╮",
    bottom_left = "╰",
    bottom_right = "╯",
    t_down = "┬",
    t_up = "┴",
  }

  return {
    rules = {
      chars.top_left,
      chars.horizontal,
      chars.t_down,
      chars.vertical,
      chars.t_up,
      chars.horizontal,
      chars.bottom_left,
      chars.vertical,
    },
    preview = {
      chars.t_down,
      chars.horizontal,
      chars.top_right,
      chars.vertical,
      chars.bottom_right,
      chars.horizontal,
      chars.t_up,
      chars.vertical,
    },
  }
end

---Calculate layout for 2-panel floating windows
---@param cols number Terminal columns
---@param lines number Terminal lines
---@return table layout
local function calculate_layout(cols, lines)
  -- Overall dimensions: 85% width x 85% height, centered
  local total_width = math.floor(cols * 0.85)
  local total_height = math.floor(lines * 0.85)
  local start_row = math.floor((lines - total_height) / 2)
  local start_col = math.floor((cols - total_width) / 2)

  -- Left panel (rules): 35% of total width
  -- Right panel (preview): 65% of total width
  local rules_width = math.floor(total_width * 0.35)
  local preview_width = total_width - rules_width - 1

  local borders = create_borders()

  local preset_name = state and state.current_preset or "SSMS Style"
  local dirty_indicator = state and state.is_dirty and " *" or ""

  return {
    rules = {
      relative = "editor",
      width = rules_width,
      height = total_height,
      row = start_row,
      col = start_col,
      style = "minimal",
      border = borders.rules,
      title = string.format(" Formatter Rules [%s]%s ", preset_name, dirty_indicator),
      title_pos = "center",
      zindex = 50,
      focusable = true,
    },
    preview = {
      relative = "editor",
      width = preview_width,
      height = total_height,
      row = start_row,
      col = start_col + rules_width + 1,
      style = "minimal",
      border = borders.preview,
      title = " Live Preview ",
      title_pos = "center",
      zindex = 50,
      focusable = true,
    },
    footer = {
      text = " h/l=Change  j/k=Navigate  p=Presets  s=Save  a=Apply  q=Cancel  <Tab>=Switch ",
      row = start_row + total_height + 2,
      col = start_col,
      width = total_width,
    },
  }
end

---Get value from config by key path
---@param config table Config table
---@param key string Key path (e.g., "indent_size" or "rules.select.one_column_per_line")
---@return any value
local function get_config_value(config, key)
  local parts = vim.split(key, ".", { plain = true })
  local current = config
  for _, part in ipairs(parts) do
    if type(current) ~= "table" then return nil end
    current = current[part]
  end
  return current
end

---Set value in config by key path
---@param config table Config table
---@param key string Key path
---@param value any Value to set
local function set_config_value(config, key, value)
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
---@return any new_value
local function cycle_forward(rule, current_value)
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
    local next_idx = current_idx % #options + 1
    return options[next_idx]
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
---@return any new_value
local function cycle_backward(rule, current_value)
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
---@return string formatted
local function format_value(rule, value)
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

-- ============================================================================
-- Public API
-- ============================================================================

---Show the rules editor UI
function RulesEditor.show()
  -- Close existing editor if open
  RulesEditor.close()

  -- Get current formatter config
  local current_config = vim.deepcopy(Config.get_formatter())

  -- Determine current preset (if any matches)
  local current_preset = nil
  local presets = Presets.list()
  for _, preset in ipairs(presets) do
    -- Simple heuristic: check if all preset values match current config
    local matches = true
    for key, val in pairs(preset.config) do
      if current_config[key] ~= val then
        matches = false
        break
      end
    end
    if matches then
      current_preset = preset.name
      break
    end
  end

  -- Initialize state
  state = {
    selected_idx = 1,
    current_config = current_config,
    original_config = vim.deepcopy(current_config),
    current_preset = current_preset or "Custom",
    original_preset = current_preset,
    is_dirty = false,
    focused_panel = "rules",
    rule_definitions = RULE_DEFINITIONS,
    rule_line_map = {},
    line_to_rule = {},
  }

  -- Create layout
  RulesEditor._create_layout()

  -- Render content
  RulesEditor._render_rules()
  RulesEditor._render_preview()

  -- Setup keymaps
  RulesEditor._setup_keymaps()

  -- Setup autocmds
  RulesEditor._setup_autocmds()
end

---Close the rules editor
function RulesEditor.close()
  if not state then return end

  -- Disable semantic highlighting on preview
  local ok, SemanticHighlighter = pcall(require, 'ssns.highlighting.semantic')
  if ok and SemanticHighlighter.disable and state.preview_buf then
    pcall(SemanticHighlighter.disable, state.preview_buf)
  end

  -- Close windows
  local windows = { state.rules_win, state.preview_win, state.footer_win }
  for _, winid in ipairs(windows) do
    if winid and vim.api.nvim_win_is_valid(winid) then
      pcall(vim.api.nvim_win_close, winid, true)
    end
  end

  -- Clear autocmds
  pcall(vim.api.nvim_del_augroup_by_name, "SSNSFormatterRulesEditor")

  state = nil
end

---Create the layout
function RulesEditor._create_layout()
  local layout = calculate_layout(vim.o.columns, vim.o.lines)

  -- Create buffers
  state.rules_buf = vim.api.nvim_create_buf(false, true)
  state.preview_buf = vim.api.nvim_create_buf(false, true)

  -- Configure buffers
  for _, bufnr in ipairs({state.rules_buf, state.preview_buf}) do
    vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  end

  -- Set filetype for preview
  vim.api.nvim_buf_set_option(state.preview_buf, 'filetype', 'sql')

  -- Create floating windows
  state.rules_win = vim.api.nvim_open_win(state.rules_buf, true, layout.rules)
  state.preview_win = vim.api.nvim_open_win(state.preview_buf, false, layout.preview)

  -- Configure windows
  for _, winid in ipairs({state.rules_win, state.preview_win}) do
    vim.api.nvim_set_option_value('number', false, { win = winid })
    vim.api.nvim_set_option_value('relativenumber', false, { win = winid })
    vim.api.nvim_set_option_value('cursorline', true, { win = winid })
    vim.api.nvim_set_option_value('wrap', false, { win = winid })
    vim.api.nvim_set_option_value('signcolumn', 'no', { win = winid })
    vim.api.nvim_set_option_value('winhighlight', 'FloatBorder:FloatBorder,FloatTitle:FloatTitle', { win = winid })
  end

  -- Disable cursorline on preview
  vim.api.nvim_set_option_value('cursorline', false, { win = state.preview_win })

  -- Create footer
  state.footer_buf = vim.api.nvim_create_buf(false, true)
  local text_len = #layout.footer.text
  local padding = math.floor((layout.footer.width - text_len) / 2)
  local centered_text = string.rep(" ", math.max(0, padding)) .. layout.footer.text

  vim.api.nvim_buf_set_lines(state.footer_buf, 0, -1, false, {centered_text})
  vim.api.nvim_buf_set_option(state.footer_buf, 'modifiable', false)

  state.footer_win = vim.api.nvim_open_win(state.footer_buf, false, {
    relative = "editor",
    width = layout.footer.width,
    height = 1,
    row = layout.footer.row,
    col = layout.footer.col,
    style = "minimal",
    border = "none",
    zindex = 52,
    focusable = false,
  })

  vim.api.nvim_set_option_value('winhighlight', 'Normal:Comment', { win = state.footer_win })

  -- Focus rules list
  vim.api.nvim_set_current_win(state.rules_win)
end

---Render the rules list
function RulesEditor._render_rules()
  local lines = {}
  local ns_id = vim.api.nvim_create_namespace("ssns_formatter_rules")

  state.rule_line_map = {}
  state.line_to_rule = {}

  -- Header
  table.insert(lines, "")

  local current_category = nil
  local rule_idx = 0

  for i, rule in ipairs(state.rule_definitions) do
    -- Add category header if new category
    if rule.category ~= current_category then
      if current_category ~= nil then
        table.insert(lines, "")  -- Blank line between categories
      end
      table.insert(lines, string.format(" ─── %s ───", rule.category))
      table.insert(lines, "")
      current_category = rule.category
    end

    rule_idx = i
    local value = get_config_value(state.current_config, rule.key)
    local display_value = format_value(rule, value)

    -- Check if value differs from original (for dirty indicator)
    local original_value = get_config_value(state.original_config, rule.key)
    local is_modified = value ~= original_value
    local modified_indicator = is_modified and "*" or " "

    local prefix = i == state.selected_idx and " ▶ " or "   "
    local line = string.format("%s%s%-22s %s[%s]", prefix, modified_indicator, rule.name, string.rep(" ", 1), display_value)

    state.rule_line_map[i] = #lines
    state.line_to_rule[#lines] = i
    table.insert(lines, line)
  end

  table.insert(lines, "")

  -- Set content
  vim.api.nvim_buf_set_option(state.rules_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.rules_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.rules_buf, 'modifiable', false)

  -- Apply highlights
  vim.api.nvim_buf_clear_namespace(state.rules_buf, ns_id, 0, -1)

  for line_idx, line in ipairs(lines) do
    local idx = line_idx - 1  -- 0-based for API
    if line:match("───") then
      -- Category header
      vim.api.nvim_buf_add_highlight(state.rules_buf, ns_id, "Comment", idx, 0, -1)
    elseif line:match("▶") then
      -- Selected row
      vim.api.nvim_buf_add_highlight(state.rules_buf, ns_id, "CursorLine", idx, 0, -1)
      vim.api.nvim_buf_add_highlight(state.rules_buf, ns_id, "Special", idx, 1, 4)
      -- Highlight value
      local bracket_start = line:find("%[")
      if bracket_start then
        vim.api.nvim_buf_add_highlight(state.rules_buf, ns_id, "String", idx, bracket_start - 1, -1)
      end
    elseif state.line_to_rule[line_idx - 1] then
      -- Regular rule row
      local bracket_start = line:find("%[")
      if bracket_start then
        vim.api.nvim_buf_add_highlight(state.rules_buf, ns_id, "Number", idx, bracket_start - 1, -1)
      end
      -- Modified indicator
      if line:sub(4, 4) == "*" then
        vim.api.nvim_buf_add_highlight(state.rules_buf, ns_id, "WarningMsg", idx, 3, 4)
      end
    end
  end

  -- Position cursor
  local cursor_line = state.rule_line_map[state.selected_idx]
  if cursor_line then
    pcall(vim.api.nvim_win_set_cursor, state.rules_win, {cursor_line + 1, 0})
  end
end

---Render the preview pane
function RulesEditor._render_preview()
  -- Format the preview SQL with current config
  local formatted = Formatter.format(PREVIEW_SQL, state.current_config)

  vim.api.nvim_buf_set_option(state.preview_buf, 'modifiable', true)
  local lines = vim.split(formatted, '\n')
  vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.preview_buf, 'modifiable', false)

  -- Apply semantic highlighting
  RulesEditor._apply_preview_highlights()
end

---Apply semantic highlighting to preview
function RulesEditor._apply_preview_highlights()
  local ok, SemanticHighlighter = pcall(require, 'ssns.highlighting.semantic')
  if ok and SemanticHighlighter.enable then
    pcall(SemanticHighlighter.enable, state.preview_buf)
    vim.defer_fn(function()
      if state and state.preview_buf and vim.api.nvim_buf_is_valid(state.preview_buf) then
        pcall(SemanticHighlighter.update, state.preview_buf)
      end
    end, 50)
  end
end

---Setup keymaps
function RulesEditor._setup_keymaps()
  local km = KeymapManager.get_group("common")

  local rules_keymaps = {
    -- Navigation
    { lhs = km.nav_down or "j", rhs = function() RulesEditor._navigate(1) end, desc = "Next rule" },
    { lhs = km.nav_up or "k", rhs = function() RulesEditor._navigate(-1) end, desc = "Previous rule" },
    { lhs = km.nav_down_alt or "<Down>", rhs = function() RulesEditor._navigate(1) end, desc = "Next rule" },
    { lhs = km.nav_up_alt or "<Up>", rhs = function() RulesEditor._navigate(-1) end, desc = "Previous rule" },

    -- Value cycling
    { lhs = "l", rhs = function() RulesEditor._cycle_value(1) end, desc = "Cycle value forward" },
    { lhs = "h", rhs = function() RulesEditor._cycle_value(-1) end, desc = "Cycle value backward" },
    { lhs = "+", rhs = function() RulesEditor._cycle_value(1) end, desc = "Cycle value forward" },
    { lhs = "-", rhs = function() RulesEditor._cycle_value(-1) end, desc = "Cycle value backward" },
    { lhs = "<Right>", rhs = function() RulesEditor._cycle_value(1) end, desc = "Cycle value forward" },
    { lhs = "<Left>", rhs = function() RulesEditor._cycle_value(-1) end, desc = "Cycle value backward" },

    -- Preset management
    { lhs = "p", rhs = function() RulesEditor._show_preset_picker() end, desc = "Select preset" },
    { lhs = "s", rhs = function() RulesEditor._save_preset() end, desc = "Save as preset" },
    { lhs = "c", rhs = function() RulesEditor._copy_preset() end, desc = "Copy preset" },
    { lhs = "r", rhs = function() RulesEditor._rename_preset() end, desc = "Rename preset" },
    { lhs = "d", rhs = function() RulesEditor._delete_preset() end, desc = "Delete preset" },

    -- Apply/Cancel
    { lhs = "a", rhs = function() RulesEditor._apply() end, desc = "Apply changes" },
    { lhs = km.confirm or "<CR>", rhs = function() RulesEditor._apply() end, desc = "Apply changes" },
    { lhs = km.cancel or "<Esc>", rhs = function() RulesEditor._cancel() end, desc = "Cancel" },
    { lhs = km.close or "q", rhs = function() RulesEditor._cancel() end, desc = "Cancel" },

    -- Panel switching
    { lhs = km.next_field or "<Tab>", rhs = function() RulesEditor._swap_focus() end, desc = "Switch panel" },

    -- Reset to original
    { lhs = "R", rhs = function() RulesEditor._reset() end, desc = "Reset to original" },
  }

  KeymapManager.set_multiple(state.rules_buf, rules_keymaps, true)
  KeymapManager.mark_group_active(state.rules_buf, "formatter_rules_editor")

  local preview_keymaps = {
    { lhs = km.cancel or "<Esc>", rhs = function() RulesEditor._cancel() end, desc = "Cancel" },
    { lhs = km.close or "q", rhs = function() RulesEditor._cancel() end, desc = "Cancel" },
    { lhs = km.next_field or "<Tab>", rhs = function() RulesEditor._swap_focus() end, desc = "Switch panel" },
    { lhs = km.prev_field or "<S-Tab>", rhs = function() RulesEditor._swap_focus() end, desc = "Switch panel" },
  }

  KeymapManager.set_multiple(state.preview_buf, preview_keymaps, true)
  KeymapManager.mark_group_active(state.preview_buf, "formatter_rules_editor")
end

---Setup autocmds
function RulesEditor._setup_autocmds()
  local group = vim.api.nvim_create_augroup("SSNSFormatterRulesEditor", { clear = true })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      if state and (
        ev.match == tostring(state.rules_win) or
        ev.match == tostring(state.preview_win)
      ) then
        RulesEditor.close()
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if state then
        RulesEditor.close()
        vim.defer_fn(function()
          RulesEditor.show()
        end, 50)
      end
    end,
  })
end

---Navigate through rules
---@param direction number 1 for down, -1 for up
function RulesEditor._navigate(direction)
  if not state then return end

  state.selected_idx = state.selected_idx + direction

  -- Wrap around
  if state.selected_idx < 1 then
    state.selected_idx = #state.rule_definitions
  elseif state.selected_idx > #state.rule_definitions then
    state.selected_idx = 1
  end

  RulesEditor._render_rules()
  RulesEditor._update_footer_description()
end

---Cycle the value of current rule
---@param direction number 1 for forward, -1 for backward
function RulesEditor._cycle_value(direction)
  if not state then return end

  local rule = state.rule_definitions[state.selected_idx]
  if not rule then return end

  local current_value = get_config_value(state.current_config, rule.key)
  local new_value

  if direction > 0 then
    new_value = cycle_forward(rule, current_value)
  else
    new_value = cycle_backward(rule, current_value)
  end

  set_config_value(state.current_config, rule.key, new_value)

  -- Mark as dirty
  state.is_dirty = true
  state.current_preset = "Custom"

  -- Update UI
  RulesEditor._render_rules()
  RulesEditor._update_title()

  -- Debounced preview update
  vim.defer_fn(function()
    if state then
      RulesEditor._render_preview()
    end
  end, 50)
end

---Swap focus between panels
function RulesEditor._swap_focus()
  if not state then return end

  if state.focused_panel == "rules" then
    state.focused_panel = "preview"
    if vim.api.nvim_win_is_valid(state.preview_win) then
      vim.api.nvim_set_current_win(state.preview_win)
      vim.api.nvim_set_option_value('cursorline', true, { win = state.preview_win })
      vim.api.nvim_set_option_value('cursorline', false, { win = state.rules_win })
    end
  else
    state.focused_panel = "rules"
    if vim.api.nvim_win_is_valid(state.rules_win) then
      vim.api.nvim_set_current_win(state.rules_win)
      vim.api.nvim_set_option_value('cursorline', true, { win = state.rules_win })
      vim.api.nvim_set_option_value('cursorline', false, { win = state.preview_win })
      -- Restore cursor position
      local cursor_line = state.rule_line_map[state.selected_idx]
      if cursor_line then
        pcall(vim.api.nvim_win_set_cursor, state.rules_win, {cursor_line + 1, 0})
      end
    end
  end
end

---Update window title to show preset and dirty state
function RulesEditor._update_title()
  if not state or not vim.api.nvim_win_is_valid(state.rules_win) then return end

  local dirty_indicator = state.is_dirty and " *" or ""
  local new_title = string.format(" Formatter Rules [%s]%s ", state.current_preset, dirty_indicator)

  vim.api.nvim_win_set_config(state.rules_win, {
    title = new_title,
    title_pos = "center",
  })
end

---Update footer to show current rule description
function RulesEditor._update_footer_description()
  if not state or not vim.api.nvim_win_is_valid(state.footer_win) then return end

  local rule = state.rule_definitions[state.selected_idx]
  if not rule then return end

  -- For now, keep the keybindings footer - could show description on hover
end

---Apply changes
function RulesEditor._apply()
  if not state then return end

  -- Apply config changes
  Config.current.formatter = state.current_config

  vim.notify("Formatter config applied", vim.log.levels.INFO)
  RulesEditor.close()
end

---Cancel and restore original
function RulesEditor._cancel()
  if not state then return end

  if state.is_dirty then
    -- Could prompt for confirmation here
  end

  RulesEditor.close()
end

---Reset to original config
function RulesEditor._reset()
  if not state then return end

  state.current_config = vim.deepcopy(state.original_config)
  state.current_preset = state.original_preset or "Custom"
  state.is_dirty = false

  RulesEditor._render_rules()
  RulesEditor._render_preview()
  RulesEditor._update_title()

  vim.notify("Reset to original config", vim.log.levels.INFO)
end

---Show preset picker
function RulesEditor._show_preset_picker()
  if not state then return end

  local presets = Presets.list()
  local items = {}

  for _, preset in ipairs(presets) do
    local label = preset.name
    if preset.is_user then
      label = label .. " (user)"
    end
    table.insert(items, { name = preset.name, label = label, file_name = preset.file_name, is_user = preset.is_user })
  end

  vim.ui.select(items, {
    prompt = "Select Preset:",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then return end

    local preset = Presets.load(choice.file_name or choice.name)
    if preset then
      -- Apply preset config
      state.current_config = vim.tbl_deep_extend("force", state.current_config, preset.config)
      state.current_preset = preset.name
      state.is_dirty = true

      RulesEditor._render_rules()
      RulesEditor._render_preview()
      RulesEditor._update_title()
    end
  end)
end

---Save current config as new preset
function RulesEditor._save_preset()
  if not state then return end

  vim.ui.input({ prompt = "Preset name: " }, function(name)
    if not name or name == "" then return end

    local file_name = name:gsub("[^%w_%-]", "_")
    local ok, err = Presets.save(file_name, name, state.current_config, "User-defined preset")

    if ok then
      state.current_preset = name
      state.is_dirty = false
      RulesEditor._update_title()
      vim.notify("Preset saved: " .. name, vim.log.levels.INFO)
    else
      vim.notify("Failed to save preset: " .. (err or "unknown error"), vim.log.levels.ERROR)
    end
  end)
end

---Copy current preset
function RulesEditor._copy_preset()
  if not state then return end

  -- If current is a known preset, copy it
  local preset = Presets.load(state.current_preset)
  if preset and not preset.is_user then
    -- Copy built-in preset to user folder
    local ok, err = Presets.copy(preset.file_name or state.current_preset)
    if ok then
      vim.notify("Preset copied to user folder", vim.log.levels.INFO)
      Presets.clear_cache()
    else
      vim.notify("Failed to copy: " .. (err or "unknown error"), vim.log.levels.ERROR)
    end
  else
    -- Save current config as new preset
    RulesEditor._save_preset()
  end
end

---Rename current preset (user only)
function RulesEditor._rename_preset()
  if not state then return end

  local preset = Presets.load(state.current_preset)
  if not preset or not preset.is_user then
    vim.notify("Can only rename user presets", vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = "New name: ", default = preset.name }, function(new_name)
    if not new_name or new_name == "" then return end

    local ok, err = Presets.rename(preset.file_name, new_name)
    if ok then
      state.current_preset = new_name
      RulesEditor._update_title()
      Presets.clear_cache()
      vim.notify("Preset renamed", vim.log.levels.INFO)
    else
      vim.notify("Failed to rename: " .. (err or "unknown error"), vim.log.levels.ERROR)
    end
  end)
end

---Delete current preset (user only)
function RulesEditor._delete_preset()
  if not state then return end

  local preset = Presets.load(state.current_preset)
  if not preset or not preset.is_user then
    vim.notify("Can only delete user presets", vim.log.levels.WARN)
    return
  end

  vim.ui.select({ "Yes", "No" }, {
    prompt = string.format("Delete preset '%s'?", preset.name),
  }, function(choice)
    if choice ~= "Yes" then return end

    local ok, err = Presets.delete(preset.file_name)
    if ok then
      state.current_preset = "Custom"
      RulesEditor._update_title()
      Presets.clear_cache()
      vim.notify("Preset deleted", vim.log.levels.INFO)
    else
      vim.notify("Failed to delete: " .. (err or "unknown error"), vim.log.levels.ERROR)
    end
  end)
end

---Check if editor is open
---@return boolean
function RulesEditor.is_open()
  return state ~= nil
end

return RulesEditor
