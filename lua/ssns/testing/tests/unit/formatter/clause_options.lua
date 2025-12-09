-- Test file: clause_options.lua
-- IDs: 8451-8520
-- Tests: Phase 1 clause options - SELECT, FROM, WHERE, JOIN specific formatting

return {
    -- SELECT clause options
    {
        id = 8451,
        type = "formatter",
        name = "select_distinct_newline true",
        input = "SELECT DISTINCT name, email FROM users",
        opts = { select_distinct_newline = true },
        expected = {
            matches = { "SELECT\n.-DISTINCT" }
        }
    },
    {
        id = 8452,
        type = "formatter",
        name = "select_distinct_newline false (default)",
        input = "SELECT DISTINCT name FROM users",
        opts = { select_distinct_newline = false },
        expected = {
            contains = { "SELECT DISTINCT" }  -- On same line
        }
    },
    {
        id = 8453,
        type = "formatter",
        name = "select_top_newline true",
        input = "SELECT TOP 10 * FROM users",
        opts = { select_top_newline = true },
        expected = {
            matches = { "SELECT\n.-TOP 10" }
        }
    },
    {
        id = 8454,
        type = "formatter",
        name = "select_top_newline false (default)",
        input = "SELECT TOP 10 * FROM users",
        opts = { select_top_newline = false },
        expected = {
            contains = { "SELECT TOP 10" }  -- On same line
        }
    },
    {
        id = 8455,
        type = "formatter",
        name = "select_into_newline true",
        input = "SELECT * INTO #temp FROM users",
        opts = { select_into_newline = true },
        expected = {
            matches = { "SELECT %*\n.-INTO" }
        }
    },

    -- JOIN clause options
    {
        id = 8460,
        type = "formatter",
        name = "empty_line_before_join true",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id",
        opts = { empty_line_before_join = true },
        expected = {
            matches = { "FROM users u\n\nINNER JOIN" }  -- Empty line before JOIN
        }
    },
    {
        id = 8461,
        type = "formatter",
        name = "empty_line_before_join false (default)",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id",
        opts = { empty_line_before_join = false },
        expected = {
            matches = { "FROM users u\nINNER JOIN" }  -- No empty line
        }
    },
    {
        id = 8462,
        type = "formatter",
        name = "join_on_same_line true",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id",
        opts = { join_on_same_line = true },
        expected = {
            contains = { "INNER JOIN orders o ON u.id = o.user_id" }
        }
    },
    {
        id = 8463,
        type = "formatter",
        name = "join_on_same_line false (default) - ON on new line",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id",
        opts = { join_on_same_line = false },
        expected = {
            matches = { "INNER JOIN orders o\n.-ON" }
        }
    },
    {
        id = 8464,
        type = "formatter",
        name = "on_and_position leading in ON clause",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id AND u.active = 1",
        opts = { on_and_position = "leading" },
        expected = {
            matches = { "ON u.id = o.user_id\n.-AND u.active" }
        }
    },
    {
        id = 8465,
        type = "formatter",
        name = "Multiple JOINs with empty_line_before_join",
        input = "SELECT * FROM a INNER JOIN b ON a.id = b.a_id LEFT JOIN c ON b.id = c.b_id",
        opts = { empty_line_before_join = true },
        expected = {
            matches = { "\n\nINNER JOIN", "\n\nLEFT JOIN" }
        }
    },

    -- WHERE clause options
    {
        id = 8470,
        type = "formatter",
        name = "and_or_position leading (default)",
        input = "SELECT * FROM users WHERE a = 1 AND b = 2 OR c = 3",
        opts = { and_or_position = "leading" },
        expected = {
            matches = { "WHERE a = 1\n.-AND b = 2\n.-OR c = 3" }
        }
    },
    {
        id = 8471,
        type = "formatter",
        name = "and_or_position trailing",
        input = "SELECT * FROM users WHERE a = 1 AND b = 2",
        opts = { and_or_position = "trailing" },
        expected = {
            contains = { "a = 1 AND", "b = 2" }  -- AND at end of line
        }
    },
    {
        id = 8472,
        type = "formatter",
        name = "where_and_or_indent custom value",
        input = "SELECT * FROM users WHERE a = 1 AND b = 2",
        opts = { and_or_position = "leading", where_and_or_indent = 2 },
        expected = {
            -- AND should be indented by 2 levels (8 spaces with default indent_size=4)
            matches = { "\n        AND" }
        }
    },

    -- GROUP BY options
    {
        id = 8480,
        type = "formatter",
        name = "group_by_style stacked",
        input = "SELECT a, b, COUNT(*) FROM t GROUP BY a, b",
        opts = { group_by_style = "stacked" },
        expected = {
            matches = { "GROUP BY a,\n.-b" }
        }
    },
    {
        id = 8481,
        type = "formatter",
        name = "group_by_style inline (default)",
        input = "SELECT a, b, COUNT(*) FROM t GROUP BY a, b",
        opts = { group_by_style = "inline" },
        expected = {
            contains = { "GROUP BY a, b" }
        }
    },

    -- ORDER BY options
    {
        id = 8485,
        type = "formatter",
        name = "order_by_style stacked",
        input = "SELECT * FROM users ORDER BY last_name, first_name",
        opts = { order_by_style = "stacked" },
        expected = {
            matches = { "ORDER BY last_name,\n.-first_name" }
        }
    },
    {
        id = 8486,
        type = "formatter",
        name = "order_by_style inline (default)",
        input = "SELECT * FROM users ORDER BY last_name, first_name",
        opts = { order_by_style = "inline" },
        expected = {
            contains = { "ORDER BY last_name, first_name" }
        }
    },
    {
        id = 8487,
        type = "formatter",
        name = "ORDER BY stacked with ASC/DESC",
        input = "SELECT * FROM users ORDER BY last_name ASC, first_name DESC",
        opts = { order_by_style = "stacked" },
        expected = {
            matches = { "ORDER BY last_name ASC,\n.-first_name DESC" }
        }
    },

    -- CTE options
    {
        id = 8490,
        type = "formatter",
        name = "cte_as_position same_line (default)",
        input = "WITH cte AS (SELECT * FROM users) SELECT * FROM cte",
        opts = { cte_as_position = "same_line" },
        expected = {
            contains = { "cte AS" }
        }
    },
    {
        id = 8491,
        type = "formatter",
        name = "cte_as_position new_line",
        input = "WITH cte AS (SELECT * FROM users) SELECT * FROM cte",
        opts = { cte_as_position = "new_line" },
        expected = {
            matches = { "cte\n.-AS" }
        }
    },
    {
        id = 8492,
        type = "formatter",
        name = "cte_parenthesis_style same_line (default)",
        input = "WITH cte AS (SELECT * FROM users) SELECT * FROM cte",
        opts = { cte_parenthesis_style = "same_line" },
        expected = {
            contains = { "AS (" }
        }
    },
    {
        id = 8493,
        type = "formatter",
        name = "cte_parenthesis_style new_line",
        input = "WITH cte AS (SELECT * FROM users) SELECT * FROM cte",
        opts = { cte_parenthesis_style = "new_line" },
        expected = {
            matches = { "AS\n.-%(" }  -- Escape ( in Lua pattern
        }
    },

    -- UNION indent
    {
        id = 8500,
        type = "formatter",
        name = "union_indent 0 (default)",
        input = "SELECT id FROM a UNION SELECT id FROM b",
        opts = { union_indent = 0 },
        expected = {
            matches = { "\nUNION\n" }  -- UNION at column 0
        }
    },

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
            -- Compact: WHEN stays on same line as CASE
            line_count = 3  -- SELECT, FROM, not many newlines in CASE
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
}
