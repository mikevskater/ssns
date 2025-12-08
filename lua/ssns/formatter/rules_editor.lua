---@class FormatterRulesEditor
---Interactive formatter rules editor with three-panel layout:
---  Left: Preset list (built-in + user)
---  Middle: Settings for selected preset
---  Right: Live SQL preview
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
---@field presets_buf number Presets list buffer
---@field presets_win number Presets list window
---@field rules_buf number Rules list buffer
---@field rules_win number Rules list window
---@field preview_buf number Preview buffer
---@field preview_win number Preview window
---@field footer_buf number Footer buffer
---@field footer_win number Footer window
---@field available_presets FormatterPreset[] All available presets
---@field selected_preset_idx number Currently selected preset index
---@field selected_rule_idx number Currently selected rule index
---@field current_config table Working copy of formatter config
---@field original_config table Original config for cancel/reset
---@field is_dirty boolean Whether config has been modified
---@field active_panel string Which panel is focused ("presets", "rules", "preview")
---@field rule_definitions RuleDefinition[] All rule definitions
---@field rule_line_map table<number, number> Rule index to line number map
---@field line_to_rule table<number, number> Line number to rule index map
---@field preset_line_map table<number, number> Preset index to line number map
---@field line_to_preset table<number, number> Line number to preset index map
---@field editing_user_copy boolean Whether we auto-created a user copy

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

  -- Clauses (legacy)
  { key = "newline_before_clause", name = "Newline Before Clause", description = "Start major clauses on new lines", type = "boolean", category = "Clauses" },
  { key = "comma_position", name = "Comma Position", description = "Place commas at start or end of line", type = "enum", options = {"trailing", "leading"}, category = "Clauses" },
  { key = "and_or_position", name = "AND/OR Position", description = "Place AND/OR at start or end of line", type = "enum", options = {"leading", "trailing"}, category = "Clauses" },

  -- SELECT Clause (Phase 1)
  { key = "select_list_style", name = "Select List Style", description = "Columns inline or one per line", type = "enum", options = {"inline", "stacked"}, category = "SELECT" },
  { key = "select_star_expand", name = "Expand SELECT *", description = "Auto-expand SELECT * to column list", type = "boolean", category = "SELECT" },
  { key = "select_distinct_newline", name = "DISTINCT Newline", description = "Put DISTINCT on new line after SELECT", type = "boolean", category = "SELECT" },
  { key = "select_top_newline", name = "TOP Newline", description = "Put TOP clause on new line after SELECT", type = "boolean", category = "SELECT" },
  { key = "select_into_newline", name = "INTO Newline", description = "Put INTO clause on new line", type = "boolean", category = "SELECT" },
  { key = "select_column_align", name = "Column Alignment", description = "Align columns to left or keyword", type = "enum", options = {"left", "keyword"}, category = "SELECT" },
  { key = "select_expression_wrap", name = "Expression Wrap", description = "Wrap expressions longer than N chars (0=disable)", type = "number", min = 0, max = 200, step = 10, category = "SELECT" },
  { key = "use_as_keyword", name = "Use AS Keyword", description = "Always use AS for column aliases", type = "boolean", category = "SELECT" },

  -- FROM Clause (Phase 1)
  { key = "from_newline", name = "FROM Newline", description = "FROM on new line", type = "boolean", category = "FROM" },
  { key = "from_table_style", name = "Table Style", description = "Tables inline or one per line", type = "enum", options = {"inline", "stacked"}, category = "FROM" },
  { key = "from_alias_align", name = "Alias Alignment", description = "Align table aliases", type = "boolean", category = "FROM" },
  { key = "from_schema_qualify", name = "Schema Qualify", description = "Schema qualification style", type = "enum", options = {"always", "never", "preserve"}, category = "FROM" },
  { key = "from_table_hints_newline", name = "Table Hints Newline", description = "Table hints on new line", type = "boolean", category = "FROM" },
  { key = "derived_table_style", name = "Derived Table Style", description = "Derived table opening paren position", type = "enum", options = {"inline", "newline"}, category = "FROM" },

  -- WHERE Clause (Phase 1)
  { key = "where_newline", name = "WHERE Newline", description = "WHERE on new line", type = "boolean", category = "WHERE" },
  { key = "where_condition_style", name = "Condition Style", description = "Conditions inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "WHERE" },
  { key = "where_and_or_indent", name = "AND/OR Indent", description = "AND/OR indent level", type = "number", min = 0, max = 4, step = 1, category = "WHERE" },
  { key = "where_in_list_style", name = "IN List Style", description = "IN list inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "WHERE" },
  { key = "where_between_style", name = "BETWEEN Style", description = "BETWEEN values inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "WHERE" },
  { key = "where_exists_style", name = "EXISTS Style", description = "EXISTS subquery inline or newline", type = "enum", options = {"inline", "newline"}, category = "WHERE" },

  -- JOIN Clause (Phase 1)
  { key = "join_on_same_line", name = "ON Same Line", description = "Keep ON clause on same line as JOIN", type = "boolean", category = "JOIN" },
  { key = "join_newline", name = "JOIN Newline", description = "JOIN on new line", type = "boolean", category = "JOIN" },
  { key = "join_keyword_style", name = "Keyword Style", description = "INNER JOIN vs JOIN", type = "enum", options = {"full", "short"}, category = "JOIN" },
  { key = "join_indent_style", name = "Indent Style", description = "JOIN alignment style", type = "enum", options = {"align", "indent"}, category = "JOIN" },
  { key = "on_condition_style", name = "ON Condition Style", description = "ON conditions inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "JOIN" },
  { key = "on_and_position", name = "ON AND Position", description = "AND in ON clause position", type = "enum", options = {"leading", "trailing"}, category = "JOIN" },
  { key = "cross_apply_newline", name = "CROSS APPLY Newline", description = "CROSS/OUTER APPLY on new line", type = "boolean", category = "JOIN" },
  { key = "empty_line_before_join", name = "Empty Line Before", description = "Empty line before JOIN", type = "boolean", category = "JOIN" },

  -- INSERT rules (Phase 2)
  { key = "insert_columns_style", name = "Columns Style", description = "INSERT column list inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "INSERT" },
  { key = "insert_values_style", name = "Values Style", description = "VALUES clause inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "INSERT" },
  { key = "insert_into_keyword", name = "INTO Keyword", description = "Always use INTO keyword", type = "boolean", category = "INSERT" },
  { key = "insert_multi_row_style", name = "Multi-Row Style", description = "Multiple VALUES rows inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "INSERT" },

  -- UPDATE rules (Phase 2)
  { key = "update_set_style", name = "SET Style", description = "SET assignments inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "UPDATE" },
  { key = "update_set_align", name = "Align SET", description = "Align = in SET clause", type = "boolean", category = "UPDATE" },

  -- DELETE rules (Phase 2)
  { key = "delete_from_keyword", name = "FROM Keyword", description = "Always use FROM keyword", type = "boolean", category = "DELETE" },

  -- OUTPUT/MERGE rules (Phase 2)
  { key = "output_clause_newline", name = "OUTPUT Newline", description = "OUTPUT clause on new line", type = "boolean", category = "DML" },
  { key = "merge_style", name = "MERGE Style", description = "MERGE statement style", type = "enum", options = {"compact", "expanded"}, category = "DML" },
  { key = "merge_when_newline", name = "WHEN Newline", description = "WHEN clauses on new lines", type = "boolean", category = "DML" },

  -- GROUP BY rules (Phase 2)
  { key = "group_by_newline", name = "Newline", description = "GROUP BY on new line", type = "boolean", category = "GROUP BY" },
  { key = "group_by_style", name = "Style", description = "GROUP BY columns inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "GROUP BY" },
  { key = "having_newline", name = "HAVING Newline", description = "HAVING on new line", type = "boolean", category = "GROUP BY" },

  -- ORDER BY rules (Phase 2)
  { key = "order_by_newline", name = "Newline", description = "ORDER BY on new line", type = "boolean", category = "ORDER BY" },
  { key = "order_by_style", name = "Style", description = "ORDER BY columns inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "ORDER BY" },
  { key = "order_direction_style", name = "Direction Style", description = "ASC/DESC display mode", type = "enum", options = {"always", "explicit", "never"}, category = "ORDER BY" },

  -- CTE rules (Phase 2)
  { key = "cte_style", name = "CTE Style", description = "CTE layout style", type = "enum", options = {"compact", "expanded"}, category = "CTE" },
  { key = "cte_as_position", name = "AS Position", description = "AS keyword on same or new line", type = "enum", options = {"same_line", "new_line"}, category = "CTE" },
  { key = "cte_parenthesis_style", name = "Paren Style", description = "Opening paren on same or new line", type = "enum", options = {"same_line", "new_line"}, category = "CTE" },
  { key = "cte_columns_style", name = "Columns Style", description = "CTE column list inline or stacked", type = "enum", options = {"inline", "stacked"}, category = "CTE" },
  { key = "cte_separator_newline", name = "Separator Newline", description = "Comma between CTEs on new line", type = "boolean", category = "CTE" },

  -- Casing rules (Phase 3)
  { key = "function_case", name = "Function Case", description = "Built-in functions casing (COUNT, SUM, etc.)", type = "enum", options = {"upper", "lower", "preserve"}, category = "Casing" },
  { key = "datatype_case", name = "Datatype Case", description = "Data types casing (INT, VARCHAR, etc.)", type = "enum", options = {"upper", "lower", "preserve"}, category = "Casing" },
  { key = "identifier_case", name = "Identifier Case", description = "Table/column names casing", type = "enum", options = {"upper", "lower", "preserve"}, category = "Casing" },
  { key = "alias_case", name = "Alias Case", description = "Alias names casing", type = "enum", options = {"upper", "lower", "preserve"}, category = "Casing" },

  -- Alignment
  { key = "align_aliases", name = "Align Aliases", description = "Vertically align AS keywords in SELECT", type = "boolean", category = "Alignment" },
  { key = "align_columns", name = "Align Columns", description = "Vertically align column expressions", type = "boolean", category = "Alignment" },

  -- Spacing rules (Phase 3)
  { key = "operator_spacing", name = "Operator Spacing", description = "Add spaces around operators (=, +, etc.)", type = "boolean", category = "Spacing" },
  { key = "parenthesis_spacing", name = "Parenthesis Spacing", description = "Add spaces inside parentheses", type = "boolean", category = "Spacing" },
  { key = "comma_spacing", name = "Comma Spacing", description = "Spaces around commas", type = "enum", options = {"before", "after", "both", "none"}, category = "Spacing" },
  { key = "semicolon_spacing", name = "Semicolon Spacing", description = "Space before semicolon", type = "boolean", category = "Spacing" },
  { key = "bracket_spacing", name = "Bracket Spacing", description = "Spaces inside brackets []", type = "boolean", category = "Spacing" },
  { key = "equals_spacing", name = "Equals Spacing", description = "Spaces around = in SET", type = "boolean", category = "Spacing" },
  { key = "concatenation_spacing", name = "Concat Spacing", description = "Spaces around + concat operator", type = "boolean", category = "Spacing" },
  { key = "comparison_spacing", name = "Comparison Spacing", description = "Spaces around <, >, etc.", type = "boolean", category = "Spacing" },

  -- Blank lines rules (Phase 3)
  { key = "blank_line_before_clause", name = "Before Clause", description = "Blank line before major clauses", type = "boolean", category = "Blank Lines" },
  { key = "blank_line_after_go", name = "After GO", description = "Blank lines after GO batch separator", type = "number", min = 0, max = 3, category = "Blank Lines" },
  { key = "blank_line_between_statements", name = "Between Statements", description = "Blank lines between statements", type = "number", min = 0, max = 3, category = "Blank Lines" },
  { key = "blank_line_before_comment", name = "Before Comment", description = "Blank line before block comments", type = "boolean", category = "Blank Lines" },
  { key = "collapse_blank_lines", name = "Collapse Blanks", description = "Collapse multiple consecutive blank lines", type = "boolean", category = "Blank Lines" },
  { key = "max_consecutive_blank_lines", name = "Max Blanks", description = "Maximum consecutive blank lines allowed", type = "number", min = 1, max = 5, category = "Blank Lines" },

  -- Comments rules (Phase 3)
  { key = "comment_position", name = "Position", description = "Comment placement", type = "enum", options = {"preserve", "above", "inline"}, category = "Comments" },
  { key = "block_comment_style", name = "Block Style", description = "Block comment formatting", type = "enum", options = {"preserve", "reformat"}, category = "Comments" },
  { key = "inline_comment_align", name = "Align Inline", description = "Align inline comments", type = "boolean", category = "Comments" },

  -- DDL rules (Phase 4)
  { key = "create_table_column_newline", name = "Column Newline", description = "Each column definition on new line", type = "boolean", category = "DDL" },
  { key = "create_table_constraint_newline", name = "Constraint Newline", description = "Constraints on new lines", type = "boolean", category = "DDL" },
  { key = "alter_table_style", name = "ALTER Style", description = "ALTER TABLE statement layout", type = "enum", options = {"compact", "expanded"}, category = "DDL" },
  { key = "drop_if_exists_style", name = "DROP IF EXISTS", description = "DROP IF EXISTS style", type = "enum", options = {"inline", "separate"}, category = "DDL" },
  { key = "index_column_style", name = "Index Columns", description = "Index column list layout", type = "enum", options = {"inline", "stacked"}, category = "DDL" },
  { key = "view_body_indent", name = "View Body Indent", description = "Indent level for view body", type = "number", min = 0, max = 4, step = 1, category = "DDL" },
  { key = "procedure_param_style", name = "Proc Params", description = "Procedure parameter layout", type = "enum", options = {"inline", "stacked"}, category = "DDL" },
  { key = "function_param_style", name = "Func Params", description = "Function parameter layout", type = "enum", options = {"inline", "stacked"}, category = "DDL" },

  -- Expression rules (Phase 4)
  { key = "case_style", name = "CASE Style", description = "CASE expression layout", type = "enum", options = {"inline", "stacked"}, category = "Expressions" },
  { key = "case_when_indent", name = "WHEN Indent", description = "WHEN clause indent level", type = "number", min = 0, max = 4, step = 1, category = "Expressions" },
  { key = "case_then_position", name = "THEN Position", description = "THEN position relative to WHEN", type = "enum", options = {"same_line", "new_line"}, category = "Expressions" },
  { key = "subquery_paren_style", name = "Subquery Paren", description = "Subquery opening paren position", type = "enum", options = {"same_line", "new_line"}, category = "Expressions" },
  { key = "function_arg_style", name = "Function Args", description = "Function argument layout", type = "enum", options = {"inline", "stacked"}, category = "Expressions" },
  { key = "in_list_style", name = "IN List Style", description = "IN clause value list layout", type = "enum", options = {"inline", "stacked"}, category = "Expressions" },
  { key = "expression_wrap_length", name = "Expr Wrap", description = "Wrap expressions at N chars (0=disable)", type = "number", min = 0, max = 200, step = 10, category = "Expressions" },
  { key = "boolean_operator_newline", name = "Bool Op Newline", description = "Put AND/OR on new lines in expressions", type = "boolean", category = "Expressions" },
}

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

---Create custom borders for 3-panel horizontal layout
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
    -- Left panel (presets): rounded left, T-junction right
    presets = {
      chars.top_left,      -- top-left
      chars.horizontal,    -- top
      chars.t_down,        -- top-right (T-junction)
      chars.vertical,      -- right
      chars.t_up,          -- bottom-right (T-junction)
      chars.horizontal,    -- bottom
      chars.bottom_left,   -- bottom-left
      chars.vertical,      -- left
    },
    -- Middle panel (rules): T-junction both sides
    rules = {
      chars.t_down,        -- top-left (T-junction)
      chars.horizontal,    -- top
      chars.t_down,        -- top-right (T-junction)
      chars.vertical,      -- right
      chars.t_up,          -- bottom-right (T-junction)
      chars.horizontal,    -- bottom
      chars.t_up,          -- bottom-left (T-junction)
      chars.vertical,      -- left
    },
    -- Right panel (preview): T-junction left, rounded right
    preview = {
      chars.t_down,        -- top-left (T-junction)
      chars.horizontal,    -- top
      chars.top_right,     -- top-right
      chars.vertical,      -- right
      chars.bottom_right,  -- bottom-right
      chars.horizontal,    -- bottom
      chars.t_up,          -- bottom-left (T-junction)
      chars.vertical,      -- left
    },
  }
end

---Calculate layout for 3-panel floating windows (horizontal)
---@param cols number Terminal columns
---@param lines number Terminal lines
---@return table layout
local function calculate_layout(cols, lines)
  -- Overall dimensions: 90% width x 85% height, centered
  local total_width = math.floor(cols * 0.90)
  local total_height = math.floor(lines * 0.85)
  local start_row = math.floor((lines - total_height) / 2)
  local start_col = math.floor((cols - total_width) / 2)

  -- Panel widths: 20% presets, 35% rules, 45% preview
  local presets_width = math.floor(total_width * 0.18)
  local rules_width = math.floor(total_width * 0.35)
  local preview_width = total_width - presets_width - rules_width - 2  -- -2 for shared borders

  local borders = create_borders()

  -- Get current preset info for title
  local preset_name = "None"
  local dirty_indicator = ""
  if state then
    local preset = state.available_presets[state.selected_preset_idx]
    if preset then
      preset_name = preset.name
      if preset.is_user then
        preset_name = preset_name .. " (user)"
      end
    end
    dirty_indicator = state.is_dirty and " *" or ""
  end

  return {
    presets = {
      relative = "editor",
      width = presets_width,
      height = total_height,
      row = start_row,
      col = start_col,
      style = "minimal",
      border = borders.presets,
      title = " Presets ",
      title_pos = "center",
      zindex = 50,
      focusable = true,
    },
    rules = {
      relative = "editor",
      width = rules_width,
      height = total_height,
      row = start_row,
      col = start_col + presets_width + 1,
      style = "minimal",
      border = borders.rules,
      title = string.format(" Settings [%s]%s ", preset_name, dirty_indicator),
      title_pos = "center",
      zindex = 50,
      focusable = true,
    },
    preview = {
      relative = "editor",
      width = preview_width,
      height = total_height,
      row = start_row,
      col = start_col + presets_width + rules_width + 2,
      style = "minimal",
      border = borders.preview,
      title = " Preview ",
      title_pos = "center",
      zindex = 50,
      focusable = true,
    },
    footer = {
      text = " j/k=Nav  h/l=Change  <Tab>=Panel  s=Save  a=Apply  R=Reset  q=Cancel ",
      row = start_row + total_height + 2,
      col = start_col,
      width = total_width,
    },
  }
end

---Get value from config by key path
---@param config table
---@param key string
---@return any
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
---@param config table
---@param key string
---@param value any
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
---@return any
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
---@return string
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
    active_panel = "presets",
    rule_definitions = RULE_DEFINITIONS,
    rule_line_map = {},
    line_to_rule = {},
    preset_line_map = {},
    line_to_preset = {},
    editing_user_copy = false,
  }

  -- Create layout
  RulesEditor._create_layout()

  -- Render all panels
  RulesEditor._render_presets()
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
  local windows = { state.presets_win, state.rules_win, state.preview_win, state.footer_win }
  for _, winid in ipairs(windows) do
    if winid and vim.api.nvim_win_is_valid(winid) then
      pcall(vim.api.nvim_win_close, winid, true)
    end
  end

  -- Clear autocmds
  pcall(vim.api.nvim_del_augroup_by_name, "SSNSFormatterRulesEditor")

  state = nil
end

---Create the 3-panel layout
function RulesEditor._create_layout()
  local layout = calculate_layout(vim.o.columns, vim.o.lines)

  -- Create buffers
  state.presets_buf = vim.api.nvim_create_buf(false, true)
  state.rules_buf = vim.api.nvim_create_buf(false, true)
  state.preview_buf = vim.api.nvim_create_buf(false, true)

  -- Configure buffers
  for _, bufnr in ipairs({state.presets_buf, state.rules_buf, state.preview_buf}) do
    vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  end

  -- Set filetype for preview
  vim.api.nvim_buf_set_option(state.preview_buf, 'filetype', 'sql')

  -- Create floating windows
  state.presets_win = vim.api.nvim_open_win(state.presets_buf, true, layout.presets)
  state.rules_win = vim.api.nvim_open_win(state.rules_buf, false, layout.rules)
  state.preview_win = vim.api.nvim_open_win(state.preview_buf, false, layout.preview)

  -- Configure windows
  for _, winid in ipairs({state.presets_win, state.rules_win, state.preview_win}) do
    vim.api.nvim_set_option_value('number', false, { win = winid })
    vim.api.nvim_set_option_value('relativenumber', false, { win = winid })
    vim.api.nvim_set_option_value('cursorline', true, { win = winid })
    vim.api.nvim_set_option_value('wrap', false, { win = winid })
    vim.api.nvim_set_option_value('signcolumn', 'no', { win = winid })
    vim.api.nvim_set_option_value('winhighlight', 'FloatBorder:FloatBorder,FloatTitle:FloatTitle', { win = winid })
  end

  -- Disable cursorline on inactive panels
  vim.api.nvim_set_option_value('cursorline', false, { win = state.rules_win })
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

  -- Focus presets list
  vim.api.nvim_set_current_win(state.presets_win)
end

---Render the presets list
function RulesEditor._render_presets()
  local lines = {}
  local ns_id = vim.api.nvim_create_namespace("ssns_formatter_presets")

  state.preset_line_map = {}
  state.line_to_preset = {}

  -- Header
  table.insert(lines, "")

  local builtin_added = false
  local user_added = false

  for i, preset in ipairs(state.available_presets) do
    -- Add section headers
    if not preset.is_user and not builtin_added then
      table.insert(lines, " ─── Built-in ───")
      table.insert(lines, "")
      builtin_added = true
    elseif preset.is_user and not user_added then
      if builtin_added then
        table.insert(lines, "")
      end
      table.insert(lines, " ─── User ───")
      table.insert(lines, "")
      user_added = true
    end

    local prefix = i == state.selected_preset_idx and " ▶ " or "   "
    local line = string.format("%s%s", prefix, preset.name)

    state.preset_line_map[i] = #lines
    state.line_to_preset[#lines] = i
    table.insert(lines, line)
  end

  table.insert(lines, "")

  -- Set content
  vim.api.nvim_buf_set_option(state.presets_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.presets_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.presets_buf, 'modifiable', false)

  -- Apply highlights
  vim.api.nvim_buf_clear_namespace(state.presets_buf, ns_id, 0, -1)

  for line_idx, line in ipairs(lines) do
    local idx = line_idx - 1
    if line:match("───") then
      vim.api.nvim_buf_add_highlight(state.presets_buf, ns_id, "Comment", idx, 0, -1)
    elseif line:match("▶") then
      vim.api.nvim_buf_add_highlight(state.presets_buf, ns_id, "CursorLine", idx, 0, -1)
      vim.api.nvim_buf_add_highlight(state.presets_buf, ns_id, "Special", idx, 1, 4)
    end
  end

  -- Position cursor
  local cursor_line = state.preset_line_map[state.selected_preset_idx]
  if cursor_line then
    pcall(vim.api.nvim_win_set_cursor, state.presets_win, {cursor_line + 1, 0})
  end
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

  for i, rule in ipairs(state.rule_definitions) do
    -- Add category header if new category
    if rule.category ~= current_category then
      if current_category ~= nil then
        table.insert(lines, "")
      end
      table.insert(lines, string.format(" ─── %s ───", rule.category))
      table.insert(lines, "")
      current_category = rule.category
    end

    local value = get_config_value(state.current_config, rule.key)
    local display_value = format_value(rule, value)

    local prefix = i == state.selected_rule_idx and " ▶ " or "   "
    local line = string.format("%s%-20s [%s]", prefix, rule.name, display_value)

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
    local idx = line_idx - 1
    if line:match("───") then
      vim.api.nvim_buf_add_highlight(state.rules_buf, ns_id, "Comment", idx, 0, -1)
    elseif line:match("▶") then
      vim.api.nvim_buf_add_highlight(state.rules_buf, ns_id, "CursorLine", idx, 0, -1)
      vim.api.nvim_buf_add_highlight(state.rules_buf, ns_id, "Special", idx, 1, 4)
      local bracket_start = line:find("%[")
      if bracket_start then
        vim.api.nvim_buf_add_highlight(state.rules_buf, ns_id, "String", idx, bracket_start - 1, -1)
      end
    elseif state.line_to_rule[line_idx - 1] then
      local bracket_start = line:find("%[")
      if bracket_start then
        vim.api.nvim_buf_add_highlight(state.rules_buf, ns_id, "Number", idx, bracket_start - 1, -1)
      end
    end
  end

  -- Position cursor
  local cursor_line = state.rule_line_map[state.selected_rule_idx]
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

---Setup keymaps for all panels
function RulesEditor._setup_keymaps()
  local km = KeymapManager.get_group("common")

  -- Common keymaps for all panels
  local common_keymaps = {
    { lhs = km.cancel or "<Esc>", rhs = function() RulesEditor._cancel() end, desc = "Cancel" },
    { lhs = km.close or "q", rhs = function() RulesEditor._cancel() end, desc = "Cancel" },
    { lhs = "a", rhs = function() RulesEditor._apply() end, desc = "Apply changes" },
    { lhs = km.next_field or "<Tab>", rhs = function() RulesEditor._next_panel() end, desc = "Next panel" },
    { lhs = km.prev_field or "<S-Tab>", rhs = function() RulesEditor._prev_panel() end, desc = "Previous panel" },
  }

  -- Presets panel keymaps
  local presets_keymaps = vim.list_extend(vim.deepcopy(common_keymaps), {
    { lhs = km.nav_down or "j", rhs = function() RulesEditor._navigate_presets(1) end, desc = "Next preset" },
    { lhs = km.nav_up or "k", rhs = function() RulesEditor._navigate_presets(-1) end, desc = "Previous preset" },
    { lhs = km.nav_down_alt or "<Down>", rhs = function() RulesEditor._navigate_presets(1) end, desc = "Next preset" },
    { lhs = km.nav_up_alt or "<Up>", rhs = function() RulesEditor._navigate_presets(-1) end, desc = "Previous preset" },
    { lhs = km.confirm or "<CR>", rhs = function() RulesEditor._select_preset() end, desc = "Select preset" },
    { lhs = "d", rhs = function() RulesEditor._delete_preset() end, desc = "Delete preset" },
    { lhs = "r", rhs = function() RulesEditor._rename_preset() end, desc = "Rename preset" },
  })

  -- Rules panel keymaps
  local rules_keymaps = vim.list_extend(vim.deepcopy(common_keymaps), {
    { lhs = km.nav_down or "j", rhs = function() RulesEditor._navigate_rules(1) end, desc = "Next rule" },
    { lhs = km.nav_up or "k", rhs = function() RulesEditor._navigate_rules(-1) end, desc = "Previous rule" },
    { lhs = km.nav_down_alt or "<Down>", rhs = function() RulesEditor._navigate_rules(1) end, desc = "Next rule" },
    { lhs = km.nav_up_alt or "<Up>", rhs = function() RulesEditor._navigate_rules(-1) end, desc = "Previous rule" },
    { lhs = "l", rhs = function() RulesEditor._cycle_value(1) end, desc = "Cycle forward" },
    { lhs = "h", rhs = function() RulesEditor._cycle_value(-1) end, desc = "Cycle backward" },
    { lhs = "+", rhs = function() RulesEditor._cycle_value(1) end, desc = "Cycle forward" },
    { lhs = "-", rhs = function() RulesEditor._cycle_value(-1) end, desc = "Cycle backward" },
    { lhs = "<Right>", rhs = function() RulesEditor._cycle_value(1) end, desc = "Cycle forward" },
    { lhs = "<Left>", rhs = function() RulesEditor._cycle_value(-1) end, desc = "Cycle backward" },
    { lhs = "s", rhs = function() RulesEditor._save_preset() end, desc = "Save preset" },
    { lhs = "R", rhs = function() RulesEditor._reset() end, desc = "Reset" },
  })

  -- Preview panel keymaps (just navigation)
  local preview_keymaps = vim.deepcopy(common_keymaps)

  -- Set keymaps
  KeymapManager.set_multiple(state.presets_buf, presets_keymaps, true)
  KeymapManager.mark_group_active(state.presets_buf, "formatter_rules_editor")

  KeymapManager.set_multiple(state.rules_buf, rules_keymaps, true)
  KeymapManager.mark_group_active(state.rules_buf, "formatter_rules_editor")

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
        ev.match == tostring(state.presets_win) or
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
        local saved_state = {
          selected_preset_idx = state.selected_preset_idx,
          selected_rule_idx = state.selected_rule_idx,
          current_config = state.current_config,
          is_dirty = state.is_dirty,
          active_panel = state.active_panel,
        }
        RulesEditor.close()
        vim.defer_fn(function()
          RulesEditor.show()
          if state then
            state.selected_preset_idx = saved_state.selected_preset_idx
            state.selected_rule_idx = saved_state.selected_rule_idx
            state.current_config = saved_state.current_config
            state.is_dirty = saved_state.is_dirty
            state.active_panel = saved_state.active_panel
            RulesEditor._render_presets()
            RulesEditor._render_rules()
            RulesEditor._render_preview()
            RulesEditor._focus_panel(saved_state.active_panel)
          end
        end, 50)
      end
    end,
  })
end

---Navigate to next panel
function RulesEditor._next_panel()
  if not state then return end

  local panels = {"presets", "rules", "preview"}
  local current_idx = 1
  for i, p in ipairs(panels) do
    if p == state.active_panel then
      current_idx = i
      break
    end
  end

  local next_idx = current_idx % #panels + 1
  RulesEditor._focus_panel(panels[next_idx])
end

---Navigate to previous panel
function RulesEditor._prev_panel()
  if not state then return end

  local panels = {"presets", "rules", "preview"}
  local current_idx = 1
  for i, p in ipairs(panels) do
    if p == state.active_panel then
      current_idx = i
      break
    end
  end

  local prev_idx = current_idx - 1
  if prev_idx < 1 then prev_idx = #panels end
  RulesEditor._focus_panel(panels[prev_idx])
end

---Focus a specific panel
---@param panel string "presets", "rules", or "preview"
function RulesEditor._focus_panel(panel)
  if not state then return end

  state.active_panel = panel

  -- Update cursorline for all panels
  vim.api.nvim_set_option_value('cursorline', panel == "presets", { win = state.presets_win })
  vim.api.nvim_set_option_value('cursorline', panel == "rules", { win = state.rules_win })
  vim.api.nvim_set_option_value('cursorline', panel == "preview", { win = state.preview_win })

  -- Focus the window
  local win_map = {
    presets = state.presets_win,
    rules = state.rules_win,
    preview = state.preview_win,
  }

  if win_map[panel] and vim.api.nvim_win_is_valid(win_map[panel]) then
    vim.api.nvim_set_current_win(win_map[panel])
  end
end

---Navigate through presets
---@param direction number 1 for down, -1 for up
function RulesEditor._navigate_presets(direction)
  if not state then return end

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

  RulesEditor._render_presets()
  RulesEditor._render_rules()
  RulesEditor._render_preview()
  RulesEditor._update_title()
end

---Select current preset (same as navigate but explicit)
function RulesEditor._select_preset()
  if not state then return end

  local preset = state.available_presets[state.selected_preset_idx]
  if preset then
    state.current_config = vim.tbl_deep_extend("force", Config.get_formatter(), preset.config)
    state.is_dirty = false
    state.editing_user_copy = false

    RulesEditor._render_rules()
    RulesEditor._render_preview()
    RulesEditor._update_title()

    -- Move to rules panel
    RulesEditor._focus_panel("rules")
  end
end

---Navigate through rules
---@param direction number 1 for down, -1 for up
function RulesEditor._navigate_rules(direction)
  if not state then return end

  state.selected_rule_idx = state.selected_rule_idx + direction

  if state.selected_rule_idx < 1 then
    state.selected_rule_idx = #state.rule_definitions
  elseif state.selected_rule_idx > #state.rule_definitions then
    state.selected_rule_idx = 1
  end

  RulesEditor._render_rules()
end

---Cycle the value of current rule
---@param direction number 1 for forward, -1 for backward
function RulesEditor._cycle_value(direction)
  if not state then return end

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
      RulesEditor._render_presets()
    else
      vim.notify("Failed to create copy: " .. (err or "unknown"), vim.log.levels.ERROR)
      return
    end
  end

  local rule = state.rule_definitions[state.selected_rule_idx]
  if not rule then return end

  local current_value = get_config_value(state.current_config, rule.key)
  local new_value

  if direction > 0 then
    new_value = cycle_forward(rule, current_value)
  else
    new_value = cycle_backward(rule, current_value)
  end

  set_config_value(state.current_config, rule.key, new_value)
  state.is_dirty = true

  RulesEditor._render_rules()
  RulesEditor._update_title()

  -- Debounced preview update
  vim.defer_fn(function()
    if state then
      RulesEditor._render_preview()
    end
  end, 50)
end

---Update the rules panel title
function RulesEditor._update_title()
  if not state or not vim.api.nvim_win_is_valid(state.rules_win) then return end

  local preset = state.available_presets[state.selected_preset_idx]
  local preset_name = preset and preset.name or "Custom"
  if preset and preset.is_user then
    preset_name = preset_name .. " (user)"
  end
  local dirty_indicator = state.is_dirty and " *" or ""

  vim.api.nvim_win_set_config(state.rules_win, {
    title = string.format(" Settings [%s]%s ", preset_name, dirty_indicator),
    title_pos = "center",
  })
end

---Apply changes
function RulesEditor._apply()
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
  RulesEditor.close()
end

---Cancel and close
function RulesEditor._cancel()
  RulesEditor.close()
end

---Reset current preset to its original values
function RulesEditor._reset()
  if not state then return end

  local preset = state.available_presets[state.selected_preset_idx]
  if preset then
    -- Reload preset from disk
    Presets.clear_cache()
    local fresh_preset = Presets.load(preset.file_name or preset.name)
    if fresh_preset then
      state.current_config = vim.tbl_deep_extend("force", Config.get_formatter(), fresh_preset.config)
      state.is_dirty = false

      RulesEditor._render_rules()
      RulesEditor._render_preview()
      RulesEditor._update_title()

      vim.notify("Reset to preset defaults", vim.log.levels.INFO)
    end
  end
end

---Save current config as a new preset
function RulesEditor._save_preset()
  if not state then return end

  local current_preset = state.available_presets[state.selected_preset_idx]
  local default_name = current_preset and current_preset.is_user and current_preset.name or Presets.generate_unique_name("Custom")

  vim.ui.input({ prompt = "Save preset as: ", default = default_name }, function(name)
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
      RulesEditor._render_presets()
      RulesEditor._update_title()

      vim.notify("Preset saved: " .. name, vim.log.levels.INFO)
    else
      vim.notify("Failed to save: " .. (err or "unknown"), vim.log.levels.ERROR)
    end
  end)
end

---Delete selected preset (user only)
function RulesEditor._delete_preset()
  if not state then return end

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
      RulesEditor._render_presets()
      RulesEditor._render_rules()
      RulesEditor._render_preview()
      RulesEditor._update_title()

      vim.notify("Preset deleted", vim.log.levels.INFO)
    else
      vim.notify("Failed to delete: " .. (err or "unknown"), vim.log.levels.ERROR)
    end
  end)
end

---Rename selected preset (user only)
function RulesEditor._rename_preset()
  if not state then return end

  local preset = state.available_presets[state.selected_preset_idx]
  if not preset or not preset.is_user then
    vim.notify("Can only rename user presets", vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = "New name: ", default = preset.name }, function(new_name)
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

      RulesEditor._render_presets()
      RulesEditor._update_title()

      vim.notify("Preset renamed", vim.log.levels.INFO)
    else
      vim.notify("Failed to rename: " .. (err or "unknown"), vim.log.levels.ERROR)
    end
  end)
end

---Check if editor is open
---@return boolean
function RulesEditor.is_open()
  return state ~= nil
end

return RulesEditor
