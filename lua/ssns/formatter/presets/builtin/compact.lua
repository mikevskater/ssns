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

    -- SELECT clause (Phase 1) - minimal/inline
    select_list_style = "inline",
    select_star_expand = false,
    select_distinct_newline = false,
    select_top_newline = false,
    select_into_newline = false,
    select_column_align = "left",
    select_expression_wrap = 0,
    use_as_keyword = false,

    -- FROM clause (Phase 1) - inline tables
    from_newline = true,
    from_table_style = "inline",
    from_alias_align = false,
    from_schema_qualify = "preserve",
    from_table_hints_newline = false,
    derived_table_style = "inline",

    -- WHERE clause (Phase 1) - inline conditions
    where_newline = true,
    where_condition_style = "inline",
    where_and_or_indent = 0,
    where_in_list_style = "inline",
    where_between_style = "inline",
    where_exists_style = "inline",

    -- JOIN clause (Phase 1) - compact joins
    join_newline = false,
    join_keyword_style = "short",
    join_indent_style = "indent",
    on_condition_style = "inline",
    on_and_position = "trailing",
    cross_apply_newline = false,
    empty_line_before_join = false,

    -- INSERT/UPDATE/DELETE (Phase 2) - compact DML
    insert_columns_style = "inline",
    insert_values_style = "inline",
    insert_into_keyword = false,
    insert_multi_row_style = "inline",
    update_set_style = "inline",
    update_set_align = false,
    delete_from_keyword = false,
    output_clause_newline = false,
    merge_style = "compact",
    merge_when_newline = false,

    -- GROUP BY/ORDER BY (Phase 2) - inline
    group_by_newline = true,
    group_by_style = "inline",
    having_newline = true,
    order_by_newline = true,
    order_by_style = "inline",
    order_direction_style = "never",

    -- CTE (Phase 2) - compact
    cte_style = "compact",
    cte_as_position = "same_line",
    cte_parenthesis_style = "same_line",
    cte_columns_style = "inline",
    cte_separator_newline = false,

    -- Casing (Phase 3) - uppercase keywords, preserve identifiers
    function_case = "upper",
    datatype_case = "upper",
    identifier_case = "preserve",
    alias_case = "preserve",

    -- Spacing (Phase 3) - minimal spacing
    comma_spacing = "after",
    semicolon_spacing = false,
    bracket_spacing = false,
    equals_spacing = true,
    concatenation_spacing = false,
    comparison_spacing = true,

    -- Blank lines (Phase 3) - minimal blank lines
    blank_line_before_clause = false,
    blank_line_after_go = 0,
    blank_line_between_statements = 0,
    blank_line_before_comment = false,
    collapse_blank_lines = true,
    max_consecutive_blank_lines = 1,

    -- Comments (Phase 3) - preserve comments
    comment_position = "preserve",
    block_comment_style = "preserve",
    inline_comment_align = false,
  },
}
