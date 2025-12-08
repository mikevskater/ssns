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

    -- SELECT clause (Phase 1) - maximum readability
    select_list_style = "stacked",
    select_star_expand = false,
    select_distinct_newline = true,
    select_top_newline = true,
    select_into_newline = true,
    select_column_align = "keyword",
    select_expression_wrap = 60,
    use_as_keyword = true,

    -- FROM clause (Phase 1) - one table per line, aligned
    from_newline = true,
    from_table_style = "stacked",
    from_alias_align = true,
    from_schema_qualify = "preserve",
    from_table_hints_newline = true,
    derived_table_style = "newline",

    -- WHERE clause (Phase 1) - stacked conditions
    where_newline = true,
    where_condition_style = "stacked",
    where_and_or_indent = 1,
    where_in_list_style = "stacked",
    where_between_style = "stacked",
    where_exists_style = "newline",

    -- JOIN clause (Phase 1) - verbose joins
    join_newline = true,
    join_keyword_style = "full",
    join_indent_style = "indent",
    on_condition_style = "stacked",
    on_and_position = "leading",
    cross_apply_newline = true,
    empty_line_before_join = true,

    -- INSERT/UPDATE/DELETE (Phase 2) - verbose DML
    insert_columns_style = "stacked",
    insert_values_style = "stacked",
    insert_into_keyword = true,
    insert_multi_row_style = "stacked",
    update_set_style = "stacked",
    update_set_align = true,
    delete_from_keyword = true,
    output_clause_newline = true,
    merge_style = "expanded",
    merge_when_newline = true,

    -- GROUP BY/ORDER BY (Phase 2) - stacked
    group_by_newline = true,
    group_by_style = "stacked",
    having_newline = true,
    order_by_newline = true,
    order_by_style = "stacked",
    order_direction_style = "always",

    -- CTE (Phase 2) - expanded
    cte_style = "expanded",
    cte_as_position = "new_line",
    cte_parenthesis_style = "new_line",
    cte_columns_style = "stacked",
    cte_separator_newline = true,

    -- Casing (Phase 3) - uppercase keywords, preserve identifiers
    function_case = "upper",
    datatype_case = "upper",
    identifier_case = "preserve",
    alias_case = "preserve",

    -- Spacing (Phase 3) - generous spacing
    comma_spacing = "after",
    semicolon_spacing = false,
    bracket_spacing = true,
    equals_spacing = true,
    concatenation_spacing = true,
    comparison_spacing = true,

    -- Blank lines (Phase 3) - generous blank lines
    blank_line_before_clause = true,
    blank_line_after_go = 2,
    blank_line_between_statements = 2,
    blank_line_before_comment = true,
    collapse_blank_lines = true,
    max_consecutive_blank_lines = 3,

    -- Comments (Phase 3) - align comments
    comment_position = "preserve",
    block_comment_style = "preserve",
    inline_comment_align = true,
  },
}
