---@class FormatterEngineConfig
---Default configuration values for the formatter engine
local M = {}

---Default formatter configuration values
---These are applied when config values are nil
M.defaults = {
  -- Basic formatting
  enabled = true,
  indent_style = "space",
  indent_size = 4,
  keyword_case = "upper",
  max_line_length = 120,
  newline_before_clause = true,
  align_aliases = false,
  align_columns = false,
  comma_position = "trailing",
  and_or_position = "leading",
  operator_spacing = true,
  parenthesis_spacing = false,
  join_on_same_line = false,
  -- Phase 1: SELECT/FROM/WHERE/JOIN
  select_distinct_newline = false,
  select_top_newline = false,
  select_into_newline = false,
  empty_line_before_join = false,
  on_and_position = "leading",
  where_and_or_indent = 1,
  -- Phase 2: DML/Grouping
  update_set_style = "stacked",
  group_by_style = "inline",
  order_by_style = "inline",
  insert_columns_style = "inline",
  insert_values_style = "inline",
  insert_multi_row_style = "stacked",
  insert_into_keyword = false,  -- Enforce INTO keyword in INSERT (default: false for backward compat)
  output_clause_newline = true,
  merge_when_newline = true,
  -- Phase 2: CTE
  cte_as_position = "same_line",
  cte_parenthesis_style = "same_line",
  cte_separator_newline = true,
  cte_indent = 1,
  -- Phase 3: Casing
  function_case = "upper",
  datatype_case = "upper",
  identifier_case = "preserve",
  alias_case = "preserve",
  use_as_keyword = false,  -- Always use AS for column/table aliases (default: false for backward compat)
  -- Phase 3: Spacing
  comma_spacing = "after",
  semicolon_spacing = false,
  bracket_spacing = false,
  equals_spacing = true,
  comparison_spacing = true,
  concatenation_spacing = true,
  -- Phase 3: Blank lines
  blank_line_before_clause = false,
  blank_line_between_statements = 1,
  blank_line_after_go = 1,
  collapse_blank_lines = true,
  max_consecutive_blank_lines = 2,
  blank_line_before_comment = false,
  -- Phase 4: Expressions
  case_style = "stacked",
  case_then_position = "same_line",
  boolean_operator_newline = false,
  -- Phase 5: Advanced
  union_indent = 0,
  continuation_indent = 1,
  -- Indentation
  subquery_indent = 1,
  case_indent = 1,
  -- DELETE formatting
  delete_from_newline = true,    -- FROM on new line after DELETE (default: true)
  delete_alias_newline = false,  -- Alias on own line after DELETE (default: false, keeps DELETE s together)
  delete_from_keyword = false,   -- Enforce FROM keyword in DELETE (default: false for backward compat)
}

---Merge provided config with defaults
---@param config table? Provided config
---@return table Merged config with defaults applied
function M.merge_with_defaults(config)
  if not config then
    return M.defaults
  end

  local merged = {}
  for k, v in pairs(M.defaults) do
    if config[k] ~= nil then
      merged[k] = config[k]
    else
      merged[k] = v
    end
  end
  -- Also copy any additional keys from config that aren't in defaults
  for k, v in pairs(config) do
    if merged[k] == nil then
      merged[k] = v
    end
  end
  return merged
end

return M
