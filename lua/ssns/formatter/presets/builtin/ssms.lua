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

    -- SELECT clause (Phase 1)
    select_list_style = "stacked",
    select_star_expand = false,
    select_distinct_newline = false,
    select_top_newline = false,
    select_into_newline = true,
    select_column_align = "left",
    select_expression_wrap = 0,
    use_as_keyword = true,

    -- FROM clause (Phase 1)
    from_newline = true,
    from_table_style = "stacked",
    from_alias_align = false,
    from_schema_qualify = "preserve",
    from_table_hints_newline = false,
    derived_table_style = "newline",

    -- WHERE clause (Phase 1)
    where_newline = true,
    where_condition_style = "stacked",
    where_and_or_indent = 1,
    where_in_list_style = "inline",
    where_between_style = "inline",
    where_exists_style = "newline",

    -- JOIN clause (Phase 1)
    join_newline = true,
    join_keyword_style = "full",
    join_indent_style = "indent",
    on_condition_style = "inline",
    on_and_position = "leading",
    cross_apply_newline = true,
    empty_line_before_join = false,

    -- INSERT/UPDATE/DELETE (Phase 2)
    insert_columns_style = "inline",
    insert_values_style = "inline",
    insert_into_keyword = true,
    insert_multi_row_style = "stacked",
    update_set_style = "stacked",
    update_set_align = false,
    delete_from_keyword = true,
    output_clause_newline = true,
    merge_style = "expanded",
    merge_when_newline = true,

    -- GROUP BY/ORDER BY (Phase 2)
    group_by_newline = true,
    group_by_style = "inline",
    having_newline = true,
    order_by_newline = true,
    order_by_style = "inline",
    order_direction_style = "explicit",

    -- CTE (Phase 2)
    cte_style = "expanded",
    cte_as_position = "same_line",
    cte_parenthesis_style = "new_line",
    cte_columns_style = "inline",
    cte_separator_newline = false,

    -- Casing (Phase 3)
    function_case = "upper",
    datatype_case = "upper",
    identifier_case = "preserve",
    alias_case = "preserve",

    -- Spacing (Phase 3)
    comma_spacing = "after",
    semicolon_spacing = false,
    bracket_spacing = false,
    equals_spacing = true,
    concatenation_spacing = true,
    comparison_spacing = true,

    -- Blank lines (Phase 3)
    blank_line_before_clause = false,
    blank_line_after_go = 1,
    blank_line_between_statements = 1,
    blank_line_before_comment = false,
    collapse_blank_lines = true,
    max_consecutive_blank_lines = 2,

    -- Comments (Phase 3)
    comment_position = "preserve",
    block_comment_style = "preserve",
    inline_comment_align = false,

    -- DDL (Phase 4)
    create_table_column_newline = true,
    create_table_constraint_newline = true,
    alter_table_style = "expanded",
    drop_if_exists_style = "inline",
    index_column_style = "inline",
    view_body_indent = 1,
    procedure_param_style = "stacked",
    function_param_style = "stacked",

    -- Expressions (Phase 4)
    case_style = "stacked",
    case_when_indent = 1,
    case_then_position = "same_line",
    subquery_paren_style = "same_line",
    function_arg_style = "inline",
    in_list_style = "inline",
    expression_wrap_length = 0,
    boolean_operator_newline = false,
  },
}
