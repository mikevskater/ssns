-- SSNS Formatter Preset: Compact Style
-- Minimal whitespace, inline style for shorter queries

return {
  name = "Compact",
  description = "Minimal formatting - 2-space indent, inline style, leading commas",
  config = {
    enabled = true,
    indent_size = 2,
    indent_style = "space",
    keyword_case = "upper",
    max_line_length = 200,
    newline_before_clause = true,
    align_aliases = false,
    align_columns = false,
    comma_position = "leading",
    join_on_same_line = true,
    subquery_indent = 1,
    case_indent = 1,
    and_or_position = "trailing",
    parenthesis_spacing = false,
    operator_spacing = true,
    preserve_comments = true,
    format_on_save = false,
  },
}
