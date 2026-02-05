-- Test file: expression_options.lua
-- IDs: 8510-8520, 8526-85292, 8546-8558
-- Tests: Expression options - CASE, IN list, subquery, function args, boolean operators

return {
    -- CASE expression options
    {
        id = 8510,
        type = "formatter",
        name = "case_style stacked (default)",
        input = "SELECT CASE WHEN a = 1 THEN 'one' WHEN a = 2 THEN 'two' ELSE 'other' END FROM t",
        opts = { case_style = "stacked" },
        expected = {
            matches = { "CASE\n.-WHEN a = 1", "WHEN a = 2", "ELSE" }
        }
    },
    {
        id = 8511,
        type = "formatter",
        name = "case_style compact",
        input = "SELECT CASE WHEN a = 1 THEN 'one' ELSE 'other' END FROM t",
        opts = { case_style = "compact" },
        expected = {
            -- Compact: entire CASE stays on one line with SELECT, FROM on next
            line_count = 2,
            contains = { "CASE WHEN a = 1 THEN 'one' ELSE 'other' END" }
        }
    },
    {
        id = 8512,
        type = "formatter",
        name = "case_then_position same_line (default)",
        input = "SELECT CASE WHEN a = 1 THEN 'one' END FROM t",
        opts = { case_then_position = "same_line" },
        expected = {
            contains = { "WHEN a = 1 THEN 'one'" }
        }
    },
    {
        id = 8513,
        type = "formatter",
        name = "case_then_position new_line",
        input = "SELECT CASE WHEN a = 1 THEN 'one' END FROM t",
        opts = { case_then_position = "new_line" },
        expected = {
            matches = { "WHEN a = 1\n.-THEN 'one'" }
        }
    },

    -- Boolean operator newline (global)
    {
        id = 8518,
        type = "formatter",
        name = "boolean_operator_newline true - affects CASE conditions",
        input = "SELECT CASE WHEN a = 1 AND b = 2 THEN 'yes' END FROM t",
        opts = { boolean_operator_newline = true },
        expected = {
            matches = { "a = 1\n.-AND b = 2" }
        }
    },
    {
        id = 8519,
        type = "formatter",
        name = "boolean_operator_newline false (default)",
        input = "SELECT CASE WHEN a = 1 AND b = 2 THEN 'yes' END FROM t",
        opts = { boolean_operator_newline = false },
        expected = {
            contains = { "a = 1 AND b = 2" }  -- Same line
        }
    },
    {
        id = 8520,
        type = "formatter",
        name = "Complex query with multiple clause options",
        input = "WITH cte AS (SELECT * FROM base) SELECT DISTINCT a, b FROM cte INNER JOIN t ON cte.id = t.cte_id WHERE x = 1 AND y = 2 GROUP BY a, b ORDER BY a DESC",
        opts = {
            empty_line_before_join = true,
            and_or_position = "leading",
            group_by_style = "stacked",
            order_by_style = "stacked"
        },
        expected = {
            contains = { "WITH cte AS", "SELECT DISTINCT" },
            matches = { "\n\nINNER JOIN", "WHERE x = 1\n.-AND y = 2", "GROUP BY a,\n", "ORDER BY a DESC" }
        }
    },

    -- in_list_style tests (global IN list, not WHERE specific)
    {
        id = 8526,
        type = "formatter",
        name = "in_list_style inline (default) - all values on one line",
        input = "SELECT * FROM users WHERE id IN (1, 2, 3, 4, 5)",
        opts = { in_list_style = "inline" },
        expected = {
            contains = { "IN (1, 2, 3, 4, 5)" }
        }
    },
    {
        id = 8527,
        type = "formatter",
        name = "in_list_style stacked - each value on new line",
        input = "SELECT * FROM users WHERE id IN (1, 2, 3)",
        opts = { in_list_style = "stacked" },
        expected = {
            matches = { "IN %(1,\n.-2,\n.-3%)" }
        }
    },
    {
        id = 8528,
        type = "formatter",
        name = "in_list_style stacked_indent - first value on new line",
        input = "SELECT * FROM users WHERE id IN (1, 2, 3)",
        opts = { in_list_style = "stacked_indent" },
        expected = {
            -- Opening paren, then newline, then values stacked
            matches = { "IN %(\n.-1,\n.-2,\n.-3" }
        }
    },
    {
        id = 8529,
        type = "formatter",
        name = "in_list_style stacked with string values",
        input = "SELECT * FROM users WHERE status IN ('active', 'pending', 'approved')",
        opts = { in_list_style = "stacked" },
        expected = {
            matches = { "IN %('active',\n.-'pending',\n.-'approved'%)" }
        }
    },
    {
        id = 85291,
        type = "formatter",
        name = "in_list_style inline - NOT IN also handled",
        input = "SELECT * FROM users WHERE id NOT IN (1, 2, 3)",
        opts = { in_list_style = "inline" },
        expected = {
            contains = { "NOT IN (1, 2, 3)" }
        }
    },
    {
        id = 85292,
        type = "formatter",
        name = "in_list_style stacked - nested function calls stay inline",
        input = "SELECT * FROM users WHERE id IN (1, GETDATE(), 3)",
        opts = { in_list_style = "stacked" },
        expected = {
            -- Function calls within IN list should stay inline
            contains = { "GETDATE()" },
            matches = { "IN %(1,\n.-GETDATE%(%),\n.-3%)" }
        }
    },

    -- subquery_paren_style tests
    {
        id = 8546,
        type = "formatter",
        name = "subquery_paren_style same_line (default) - IN subquery",
        input = "SELECT * FROM users WHERE id IN (SELECT user_id FROM orders)",
        opts = { subquery_paren_style = "same_line" },
        expected = {
            -- Opening paren stays on same line as IN
            contains = { "IN (" }
        }
    },
    {
        id = 8547,
        type = "formatter",
        name = "subquery_paren_style new_line - IN subquery",
        input = "SELECT * FROM users WHERE id IN (SELECT user_id FROM orders)",
        opts = { subquery_paren_style = "new_line" },
        expected = {
            -- Opening paren goes to new line
            matches = { "IN\n%s*%(" }
        }
    },
    {
        id = 8548,
        type = "formatter",
        name = "subquery_paren_style same_line - EXISTS subquery",
        input = "SELECT * FROM users WHERE EXISTS (SELECT 1 FROM orders WHERE orders.user_id = users.id)",
        opts = { subquery_paren_style = "same_line" },
        expected = {
            contains = { "EXISTS (" }
        }
    },
    {
        id = 8549,
        type = "formatter",
        name = "subquery_paren_style new_line - EXISTS subquery",
        input = "SELECT * FROM users WHERE EXISTS (SELECT 1 FROM orders WHERE orders.user_id = users.id)",
        opts = { subquery_paren_style = "new_line" },
        expected = {
            matches = { "EXISTS\n%s*%(" }
        }
    },
    {
        id = 8550,
        type = "formatter",
        name = "subquery_paren_style same_line - derived table FROM",
        input = "SELECT * FROM (SELECT id, name FROM users) AS u",
        opts = { subquery_paren_style = "same_line" },
        expected = {
            contains = { "FROM (" }
        }
    },
    {
        id = 8551,
        type = "formatter",
        name = "subquery_paren_style new_line - derived table FROM",
        input = "SELECT * FROM (SELECT id, name FROM users) AS u",
        opts = { subquery_paren_style = "new_line" },
        expected = {
            matches = { "FROM\n%s*%(" }
        }
    },

    -- function_arg_style tests
    {
        id = 8552,
        type = "formatter",
        name = "function_arg_style inline (default) - COALESCE",
        input = "SELECT COALESCE(a, b, c) FROM users",
        opts = { function_arg_style = "inline" },
        expected = {
            contains = { "COALESCE(a, b, c)" }
        }
    },
    {
        id = 8553,
        type = "formatter",
        name = "function_arg_style stacked - COALESCE",
        input = "SELECT COALESCE(a, b, c) FROM users",
        opts = { function_arg_style = "stacked" },
        expected = {
            -- Args separated by newlines after commas
            matches = { "COALESCE%(a,\n%s*b,\n%s*c%)" }
        }
    },
    {
        id = 8554,
        type = "formatter",
        name = "function_arg_style inline - nested functions",
        input = "SELECT CONCAT(UPPER(a), LOWER(b)) FROM users",
        opts = { function_arg_style = "inline" },
        expected = {
            contains = { "CONCAT(UPPER(a), LOWER(b))" }
        }
    },
    {
        id = 8555,
        type = "formatter",
        name = "function_arg_style stacked - nested functions",
        input = "SELECT CONCAT(UPPER(a), LOWER(b)) FROM users",
        opts = { function_arg_style = "stacked" },
        expected = {
            -- Outer function args stacked after commas, inner stay inline
            matches = { "CONCAT%(UPPER%(a%),\n%s*LOWER%(b%)%)" }
        }
    },
    {
        id = 8556,
        type = "formatter",
        name = "function_arg_style inline - aggregate with single arg",
        input = "SELECT COUNT(id), SUM(amount) FROM orders",
        opts = { function_arg_style = "inline" },
        expected = {
            contains = { "COUNT(id)", "SUM(amount)" }
        }
    },
    {
        id = 8557,
        type = "formatter",
        name = "function_arg_style stacked - single arg functions stay inline",
        input = "SELECT COUNT(id), SUM(amount) FROM orders",
        opts = { function_arg_style = "stacked" },
        expected = {
            -- Single arg functions should stay inline
            contains = { "COUNT(id)", "SUM(amount)" }
        }
    },
    {
        id = 8558,
        type = "formatter",
        name = "function_arg_style stacked_indent - COALESCE",
        input = "SELECT COALESCE(a, b, c) FROM users",
        opts = { function_arg_style = "stacked_indent" },
        expected = {
            -- stacked_indent puts first arg on new line after (
            matches = { "COALESCE%(\n%s+a,\n%s+b,\n%s+c%)" }
        }
    },
}
