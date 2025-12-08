-- SSNS Formatter Preset: Verbose Style
-- Maximum readability with generous whitespace

return {
  name = "Verbose",
  description = "Maximum readability - aligned columns, spaced parentheses, one item per line",
  config = {
    enabled = true,
    indent_size = 4,
    indent_style = "space",
    keyword_case = "upper",
    max_line_length = 80,
    newline_before_clause = true,
    align_aliases = true,
    align_columns = true,
    comma_position = "trailing",
    join_on_same_line = false,
    subquery_indent = 2,
    case_indent = 2,
    and_or_position = "leading",
    parenthesis_spacing = true,
    operator_spacing = true,
    preserve_comments = true,
    format_on_save = false,
  },
}
