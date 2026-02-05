-- Test file: grouping_options.lua
-- IDs: 8480-8487, 8490-8493, 8500, 8559-8566, 8740-8749, 9085-9095
-- Tests: GROUP BY, ORDER BY, CTE, UNION options, cte_style

return {
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

    -- group_by_newline, having_newline, order_by_newline tests
    {
        id = 8559,
        type = "formatter",
        name = "group_by_newline true (default)",
        input = "SELECT a, COUNT(*) FROM users GROUP BY a",
        opts = { group_by_newline = true },
        expected = {
            matches = { "users\nGROUP BY" }
        }
    },
    {
        id = 8560,
        type = "formatter",
        name = "group_by_newline false",
        input = "SELECT a, COUNT(*) FROM users GROUP BY a",
        opts = { group_by_newline = false },
        expected = {
            contains = { "users GROUP BY" }
        }
    },
    {
        id = 8561,
        type = "formatter",
        name = "having_newline true (default)",
        input = "SELECT a FROM users GROUP BY a HAVING COUNT(*) > 1",
        opts = { having_newline = true },
        expected = {
            matches = { "a\nHAVING" }
        }
    },
    {
        id = 8562,
        type = "formatter",
        name = "having_newline false",
        input = "SELECT a FROM users GROUP BY a HAVING COUNT(*) > 1",
        opts = { having_newline = false },
        expected = {
            contains = { "a HAVING" }
        }
    },
    {
        id = 8563,
        type = "formatter",
        name = "order_by_newline true (default)",
        input = "SELECT a FROM users ORDER BY a",
        opts = { order_by_newline = true },
        expected = {
            matches = { "users\nORDER BY" }
        }
    },
    {
        id = 8564,
        type = "formatter",
        name = "order_by_newline false",
        input = "SELECT a FROM users ORDER BY a",
        opts = { order_by_newline = false },
        expected = {
            contains = { "users ORDER BY" }
        }
    },
    {
        id = 8565,
        type = "formatter",
        name = "all clause newlines disabled",
        input = "SELECT a FROM users GROUP BY a HAVING COUNT(*) > 1 ORDER BY a",
        opts = { group_by_newline = false, having_newline = false, order_by_newline = false },
        expected = {
            contains = { "users GROUP BY a HAVING COUNT(*) > 1 ORDER BY a" }
        }
    },
    {
        id = 8566,
        type = "formatter",
        name = "ORDER BY in OVER clause - not affected by order_by_newline",
        input = "SELECT ROW_NUMBER() OVER (ORDER BY id) FROM users",
        opts = { order_by_newline = true },
        expected = {
            -- ORDER BY inside OVER should stay inline
            contains = { "OVER (ORDER BY" }
        }
    },

    -- cte_columns_style tests
    {
        id = 8740,
        type = "formatter",
        name = "cte_columns_style inline (default) - all columns on one line",
        input = "WITH cte (col1, col2, col3) AS (SELECT a, b, c FROM t) SELECT * FROM cte",
        opts = { cte_columns_style = "inline" },
        expected = {
            -- Space between cte name and ( may or may not be present
            matches = { "cte%s*%(col1, col2, col3%)" }
        }
    },
    {
        id = 8741,
        type = "formatter",
        name = "cte_columns_style stacked - each column on new line",
        input = "WITH cte (col1, col2, col3) AS (SELECT a, b, c FROM t) SELECT * FROM cte",
        opts = { cte_columns_style = "stacked" },
        expected = {
            matches = { "cte%s*%(col1,\n.-col2,\n.-col3%)" }
        }
    },
    {
        id = 8742,
        type = "formatter",
        name = "cte_columns_style stacked_indent - first column on new line",
        input = "WITH cte (col1, col2, col3) AS (SELECT a, b, c FROM t) SELECT * FROM cte",
        opts = { cte_columns_style = "stacked_indent" },
        expected = {
            matches = { "cte%s*%(\n.-col1,\n.-col2,\n.-col3" }
        }
    },
    {
        id = 8743,
        type = "formatter",
        name = "cte_columns_style stacked - CTE without column list unaffected",
        input = "WITH cte AS (SELECT a, b FROM t) SELECT * FROM cte",
        opts = { cte_columns_style = "stacked" },
        expected = {
            -- CTE without column list should work normally
            contains = { "WITH cte AS" }
        }
    },
    {
        id = 8744,
        type = "formatter",
        name = "cte_columns_style stacked - multiple CTEs",
        input = "WITH cte1 (a, b) AS (SELECT 1, 2), cte2 (x, y) AS (SELECT 3, 4) SELECT * FROM cte1, cte2",
        opts = { cte_columns_style = "stacked" },
        expected = {
            -- Both CTEs should have stacked columns (no space between name and paren)
            matches = { "cte1%s*%(a,\n.-b%)", "cte2%s*%(x,\n.-y%)" }
        }
    },
    {
        id = 8745,
        type = "formatter",
        name = "cte_columns_style inline - many columns stay on one line",
        input = "WITH cte (a, b, c, d, e) AS (SELECT 1, 2, 3, 4, 5) SELECT * FROM cte",
        opts = { cte_columns_style = "inline" },
        expected = {
            contains = { "(a, b, c, d, e)" }
        }
    },
    {
        id = 8746,
        type = "formatter",
        name = "cte_columns_style stacked - bracket identifiers",
        input = "WITH cte ([col 1], [col 2]) AS (SELECT 1, 2) SELECT * FROM cte",
        opts = { cte_columns_style = "stacked" },
        expected = {
            matches = { "%[col 1%],\n.-%[col 2%]" }
        }
    },
    {
        id = 8747,
        type = "formatter",
        name = "cte_columns_style stacked - RECURSIVE CTE",
        input = "WITH RECURSIVE cte (n) AS (SELECT 1 UNION ALL SELECT n+1 FROM cte WHERE n < 10) SELECT * FROM cte",
        opts = { cte_columns_style = "stacked" },
        expected = {
            -- Single column CTE - no comma, just verify structure works (no space between name and paren)
            matches = { "RECURSIVE cte%s*%(n%)" }
        }
    },
    {
        id = 8748,
        type = "formatter",
        name = "cte_columns_style stacked_indent - closing paren after last column",
        input = "WITH cte (a, b) AS (SELECT 1, 2) SELECT * FROM cte",
        opts = { cte_columns_style = "stacked_indent" },
        expected = {
            -- First column on new line after (, closing paren on same line as last column
            matches = { "cte%s*%(\n.-a,\n.-b%)" }
        }
    },
    {
        id = 8749,
        type = "formatter",
        name = "cte_columns_style inline - preserves column order",
        input = "WITH cte (z_col, a_col, m_col) AS (SELECT 1, 2, 3) SELECT * FROM cte",
        opts = { cte_columns_style = "inline" },
        expected = {
            contains = { "(z_col, a_col, m_col)" }
        }
    },

    -- cte_style tests
    {
        id = 9085,
        type = "formatter",
        name = "cte_style expanded (default) - CTE body has newlines",
        input = "WITH cte AS (SELECT id, name FROM users WHERE active = 1) SELECT * FROM cte",
        opts = { cte_style = "expanded" },
        expected = {
            -- Expanded mode: FROM and WHERE on new lines inside CTE
            matches = { "AS %(\n.-SELECT", "\n.-FROM users", "\n.-WHERE active" }
        }
    },
    {
        id = 9086,
        type = "formatter",
        name = "cte_style compact - CTE body stays inline",
        input = "WITH cte AS (SELECT id, name FROM users WHERE active = 1) SELECT * FROM cte",
        opts = { cte_style = "compact" },
        expected = {
            -- Compact mode: clauses stay on same line inside CTE
            contains = { "SELECT id, name FROM users WHERE active = 1" }
        }
    },
    {
        id = 9087,
        type = "formatter",
        name = "cte_style compact - stacked select_list_style suppressed in CTE",
        input = "WITH cte AS (SELECT a, b, c FROM users) SELECT * FROM cte",
        opts = { cte_style = "compact", select_list_style = "stacked" },
        expected = {
            -- Inside CTE: columns stay inline despite stacked style
            contains = { "SELECT a, b, c FROM" }
        }
    },
    {
        id = 9088,
        type = "formatter",
        name = "cte_style compact - main query still uses stacked style",
        input = "WITH cte AS (SELECT * FROM users) SELECT a, b, c FROM cte",
        opts = { cte_style = "compact", select_list_style = "stacked" },
        expected = {
            -- Main query outside CTE should still use stacked style
            matches = { "SELECT a,\n.-b,\n.-c\nFROM cte" }
        }
    },
    {
        id = 9089,
        type = "formatter",
        name = "cte_style compact - multiple CTEs all compact",
        input = "WITH cte1 AS (SELECT id FROM a WHERE x = 1), cte2 AS (SELECT id FROM b WHERE y = 2) SELECT * FROM cte1 JOIN cte2 ON cte1.id = cte2.id",
        opts = { cte_style = "compact" },
        expected = {
            -- Both CTE bodies should be compact
            contains = { "SELECT id FROM a WHERE x = 1", "SELECT id FROM b WHERE y = 2" }
        }
    },
    {
        id = 9090,
        type = "formatter",
        name = "cte_style expanded - multiple CTEs all expanded",
        input = "WITH cte1 AS (SELECT id FROM a WHERE x = 1), cte2 AS (SELECT id FROM b WHERE y = 2) SELECT * FROM cte1 JOIN cte2 ON cte1.id = cte2.id",
        opts = { cte_style = "expanded" },
        expected = {
            -- Both CTE bodies should have newlines
            matches = { "\n.-FROM a\n.-WHERE x", "\n.-FROM b\n.-WHERE y" }
        }
    },
    {
        id = 9091,
        type = "formatter",
        name = "cte_style compact - with GROUP BY inside CTE",
        input = "WITH cte AS (SELECT category, COUNT(*) as cnt FROM products GROUP BY category) SELECT * FROM cte",
        opts = { cte_style = "compact" },
        expected = {
            -- GROUP BY stays inline in compact mode
            contains = { "FROM products GROUP BY category" }
        }
    },
    {
        id = 9092,
        type = "formatter",
        name = "cte_style compact - with ORDER BY inside CTE",
        input = "WITH cte AS (SELECT TOP 10 id, name FROM users ORDER BY created_at) SELECT * FROM cte",
        opts = { cte_style = "compact" },
        expected = {
            -- ORDER BY stays inline in compact mode
            contains = { "FROM users ORDER BY" }
        }
    },
    {
        id = 9093,
        type = "formatter",
        name = "cte_style compact - with JOIN inside CTE",
        input = "WITH cte AS (SELECT u.id, o.total FROM users u INNER JOIN orders o ON u.id = o.user_id) SELECT * FROM cte",
        opts = { cte_style = "compact" },
        expected = {
            -- JOIN stays inline in compact mode
            contains = { "FROM users u INNER JOIN orders o ON" }
        }
    },
    {
        id = 9094,
        type = "formatter",
        name = "cte_style compact - preserves other CTE options",
        input = "WITH cte AS (SELECT * FROM users) SELECT * FROM cte",
        opts = { cte_style = "compact", cte_parenthesis_style = "new_line" },
        expected = {
            -- cte_parenthesis_style should still work (open paren on new line)
            matches = { "AS\n.-%(" }
        }
    },
    {
        id = 9095,
        type = "formatter",
        name = "cte_style expanded - stacked_indent in CTE body",
        input = "WITH cte AS (SELECT id, name FROM users) SELECT * FROM cte",
        opts = { cte_style = "expanded", select_list_style = "stacked_indent" },
        expected = {
            -- stacked_indent should work inside CTE in expanded mode
            matches = { "SELECT\n.-id,\n.-name" }
        }
    },
}
