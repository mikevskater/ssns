-- SSNS Formatter Preset: SSMS Style
-- SQL Server Management Studio formatting style (default)

return {
  name = "SSMS Style",
  description = "SQL Server Management Studio formatting - uppercase keywords, 4-space indent, clauses on new lines",
  config = {
    enabled = true,
    indent_size = 4,
    indent_style = "space",
    keyword_case = "upper",
    max_line_length = 120,
    newline_before_clause = true,
    align_aliases = false,
    align_columns = false,
    comma_position = "trailing",
    join_on_same_line = false,
    subquery_indent = 1,
    case_indent = 1,
    and_or_position = "leading",
    parenthesis_spacing = false,
    operator_spacing = true,
    preserve_comments = true,
    format_on_save = false,
  },
}
