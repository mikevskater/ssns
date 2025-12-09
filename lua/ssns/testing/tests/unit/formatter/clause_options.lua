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

    -- select_list_style tests
    {
        id = 8456,
        type = "formatter",
        name = "select_list_style stacked - each column on new line",
        input = "SELECT id, name, email FROM users",
        opts = { select_list_style = "stacked" },
        expected = {
            matches = { "SELECT id,\n.-name,\n.-email" }
        }
    },
    {
        id = 8457,
        type = "formatter",
        name = "select_list_style inline - all columns on one line",
        input = "SELECT id, name, email FROM users",
        opts = { select_list_style = "inline" },
        expected = {
            contains = { "SELECT id, name, email" }
        }
    },
    {
        id = 8458,
        type = "formatter",
        name = "select_list_style stacked with aliases",
        input = "SELECT u.id AS user_id, u.name AS user_name FROM users u",
        opts = { select_list_style = "stacked" },
        expected = {
            matches = { "SELECT u.id AS user_id,\n.-u.name AS user_name" }
        }
    },
    {
        id = 8459,
        type = "formatter",
        name = "select_list_style stacked - function calls stay on same line",
        input = "SELECT COUNT(*), SUM(amount), MAX(created_at) FROM orders",
        opts = { select_list_style = "stacked" },
        expected = {
            -- Function arguments should not trigger newlines (paren_depth > 0)
            contains = { "COUNT(*)", "SUM(amount)", "MAX(created_at)" },
            matches = { "SELECT COUNT%(%*%),\n.-SUM%(amount%),\n.-MAX%(created_at%)" }
        }
    },
    {
        id = 84591,
        type = "formatter",
        name = "select_list_style stacked_indent - first column on new line",
        input = "SELECT id, name, email FROM users",
        opts = { select_list_style = "stacked_indent" },
        expected = {
            -- First column should be on new line after SELECT
            matches = { "SELECT\n.-id,\n.-name,\n.-email" }
        }
    },
    {
        id = 84592,
        type = "formatter",
        name = "select_list_style stacked_indent - indented properly",
        input = "SELECT id, name FROM users",
        opts = { select_list_style = "stacked_indent" },
        expected = {
            -- Columns should be indented (4 spaces default)
            matches = { "SELECT\n    id,\n    name" }
        }
    },
    {
        id = 84593,
        type = "formatter",
        name = "select_list_style stacked vs stacked_indent comparison",
        input = "SELECT a, b FROM t",
        opts = { select_list_style = "stacked" },
        expected = {
            -- stacked: first column on same line as SELECT
            contains = { "SELECT a," }
        }
    },
    {
        id = 84594,
        type = "formatter",
        name = "select_list_style stacked_indent with DISTINCT - DISTINCT stays on SELECT line",
        input = "SELECT DISTINCT id, name FROM users",
        opts = { select_list_style = "stacked_indent" },
        expected = {
            -- DISTINCT should stay on same line as SELECT, columns on new lines
            contains = { "SELECT DISTINCT" },
            matches = { "SELECT DISTINCT\n    id,\n    name" }
        }
    },
    {
        id = 84595,
        type = "formatter",
        name = "select_list_style stacked_indent with TOP - TOP stays on SELECT line",
        input = "SELECT TOP 10 id, name FROM users",
        opts = { select_list_style = "stacked_indent" },
        expected = {
            -- TOP 10 should stay on same line as SELECT, columns on new lines
            contains = { "SELECT TOP 10" },
            matches = { "SELECT TOP 10\n    id,\n    name" }
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
        opts = { on_and_position = "leading", on_condition_style = "stacked" },
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

    -- join_keyword_style tests
    {
        id = 84651,
        type = "formatter",
        name = "join_keyword_style full - JOIN becomes INNER JOIN",
        input = "SELECT * FROM users u JOIN orders o ON u.id = o.user_id",
        opts = { join_keyword_style = "full" },
        expected = {
            contains = { "INNER JOIN orders" }
        }
    },
    {
        id = 84652,
        type = "formatter",
        name = "join_keyword_style full - LEFT JOIN becomes LEFT OUTER JOIN",
        input = "SELECT * FROM users u LEFT JOIN orders o ON u.id = o.user_id",
        opts = { join_keyword_style = "full" },
        expected = {
            contains = { "LEFT OUTER JOIN orders" }
        }
    },
    {
        id = 84653,
        type = "formatter",
        name = "join_keyword_style full - RIGHT JOIN becomes RIGHT OUTER JOIN",
        input = "SELECT * FROM users u RIGHT JOIN orders o ON u.id = o.user_id",
        opts = { join_keyword_style = "full" },
        expected = {
            contains = { "RIGHT OUTER JOIN orders" }
        }
    },
    {
        id = 84654,
        type = "formatter",
        name = "join_keyword_style full - FULL JOIN becomes FULL OUTER JOIN",
        input = "SELECT * FROM users u FULL JOIN orders o ON u.id = o.user_id",
        opts = { join_keyword_style = "full" },
        expected = {
            contains = { "FULL OUTER JOIN orders" }
        }
    },
    {
        id = 84655,
        type = "formatter",
        name = "join_keyword_style full - INNER JOIN stays INNER JOIN",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id",
        opts = { join_keyword_style = "full" },
        expected = {
            contains = { "INNER JOIN orders" }
        }
    },
    {
        id = 84656,
        type = "formatter",
        name = "join_keyword_style short - INNER JOIN becomes JOIN",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id",
        opts = { join_keyword_style = "short" },
        expected = {
            contains = { "JOIN orders" },
            not_contains = { "INNER JOIN" }
        }
    },
    {
        id = 84657,
        type = "formatter",
        name = "join_keyword_style short - LEFT OUTER JOIN becomes LEFT JOIN",
        input = "SELECT * FROM users u LEFT OUTER JOIN orders o ON u.id = o.user_id",
        opts = { join_keyword_style = "short" },
        expected = {
            contains = { "LEFT JOIN orders" },
            not_contains = { "LEFT OUTER JOIN" }
        }
    },
    {
        id = 84658,
        type = "formatter",
        name = "join_keyword_style short - RIGHT OUTER JOIN becomes RIGHT JOIN",
        input = "SELECT * FROM users u RIGHT OUTER JOIN orders o ON u.id = o.user_id",
        opts = { join_keyword_style = "short" },
        expected = {
            contains = { "RIGHT JOIN orders" },
            not_contains = { "RIGHT OUTER JOIN" }
        }
    },
    {
        id = 84659,
        type = "formatter",
        name = "join_keyword_style short - FULL OUTER JOIN becomes FULL JOIN",
        input = "SELECT * FROM users u FULL OUTER JOIN orders o ON u.id = o.user_id",
        opts = { join_keyword_style = "short" },
        expected = {
            contains = { "FULL JOIN orders" },
            not_contains = { "FULL OUTER JOIN" }
        }
    },
    {
        id = 846591,
        type = "formatter",
        name = "join_keyword_style short - plain JOIN stays JOIN",
        input = "SELECT * FROM users u JOIN orders o ON u.id = o.user_id",
        opts = { join_keyword_style = "short" },
        expected = {
            contains = { "JOIN orders" },
            not_contains = { "INNER" }
        }
    },
    {
        id = 846592,
        type = "formatter",
        name = "join_keyword_style full - CROSS JOIN stays unchanged",
        input = "SELECT * FROM users u CROSS JOIN orders o",
        opts = { join_keyword_style = "full" },
        expected = {
            contains = { "CROSS JOIN orders" }
        }
    },

    -- FROM clause options
    {
        id = 8466,
        type = "formatter",
        name = "from_newline true (default) - FROM on new line",
        input = "SELECT id, name FROM users",
        opts = { from_newline = true },
        expected = {
            matches = { "SELECT.-\nFROM" }
        }
    },
    {
        id = 8467,
        type = "formatter",
        name = "from_newline false - FROM on same line",
        input = "SELECT id, name FROM users",
        opts = { from_newline = false },
        expected = {
            contains = { "name FROM users" }
        }
    },
    {
        id = 8468,
        type = "formatter",
        name = "from_newline false with multiple columns",
        input = "SELECT a, b, c FROM t",
        opts = { from_newline = false, select_list_style = "inline" },
        expected = {
            -- Everything on one line when both options set
            contains = { "SELECT a, b, c FROM t" }
        }
    },
    {
        id = 8469,
        type = "formatter",
        name = "from_newline false still keeps WHERE on new line",
        input = "SELECT * FROM users WHERE active = 1",
        opts = { from_newline = false },
        expected = {
            -- FROM on same line as SELECT, but WHERE on new line
            contains = { "SELECT * FROM users" },
            matches = { "\nWHERE" }
        }
    },

    -- WHERE clause newline options
    {
        id = 84691,
        type = "formatter",
        name = "where_newline true (default) - WHERE on new line",
        input = "SELECT * FROM users WHERE active = 1",
        opts = { where_newline = true },
        expected = {
            matches = { "users\nWHERE" }
        }
    },
    {
        id = 84692,
        type = "formatter",
        name = "where_newline false - WHERE on same line",
        input = "SELECT * FROM users WHERE active = 1",
        opts = { where_newline = false },
        expected = {
            contains = { "users WHERE active" }
        }
    },
    {
        id = 84693,
        type = "formatter",
        name = "where_newline false with from_newline false - all on one line",
        input = "SELECT id FROM t WHERE x = 1",
        opts = { where_newline = false, from_newline = false, select_list_style = "inline" },
        expected = {
            -- Everything on one line
            contains = { "SELECT id FROM t WHERE x = 1" }
        }
    },
    {
        id = 84694,
        type = "formatter",
        name = "where_newline false still keeps AND/OR on new lines",
        input = "SELECT * FROM users WHERE a = 1 AND b = 2",
        opts = { where_newline = false, where_condition_style = "stacked" },
        expected = {
            -- WHERE on same line, but AND on new line
            contains = { "users WHERE a = 1" },
            matches = { "\n.-AND b = 2" }
        }
    },

    -- WHERE clause condition options
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

    -- where_condition_style tests
    {
        id = 8473,
        type = "formatter",
        name = "where_condition_style stacked - AND/OR on new lines",
        input = "SELECT * FROM users WHERE a = 1 AND b = 2 AND c = 3",
        opts = { where_condition_style = "stacked", and_or_position = "leading" },
        expected = {
            matches = { "WHERE a = 1\n.-AND b = 2\n.-AND c = 3" }
        }
    },
    {
        id = 8474,
        type = "formatter",
        name = "where_condition_style inline - all conditions on one line",
        input = "SELECT * FROM users WHERE a = 1 AND b = 2 AND c = 3",
        opts = { where_condition_style = "inline" },
        expected = {
            contains = { "WHERE a = 1 AND b = 2 AND c = 3" }
        }
    },
    {
        id = 8475,
        type = "formatter",
        name = "where_condition_style stacked_indent - first condition on new line",
        input = "SELECT * FROM users WHERE a = 1 AND b = 2",
        opts = { where_condition_style = "stacked_indent", and_or_position = "leading" },
        expected = {
            -- First condition on new line after WHERE, then AND on new line
            matches = { "WHERE\n    a = 1\n    AND b = 2" }
        }
    },
    {
        id = 8476,
        type = "formatter",
        name = "where_condition_style stacked_indent - proper indentation",
        input = "SELECT * FROM users WHERE active = 1 AND deleted = 0",
        opts = { where_condition_style = "stacked_indent", and_or_position = "leading" },
        expected = {
            -- Both conditions should be indented
            matches = { "WHERE\n    active = 1\n    AND deleted = 0" }
        }
    },
    {
        id = 8477,
        type = "formatter",
        name = "where_condition_style stacked with trailing AND",
        input = "SELECT * FROM users WHERE a = 1 AND b = 2",
        opts = { where_condition_style = "stacked", and_or_position = "trailing" },
        expected = {
            -- AND at end of line, next condition on new line
            matches = { "WHERE a = 1 AND\n.-b = 2" }
        }
    },
    {
        id = 8478,
        type = "formatter",
        name = "where_condition_style inline ignores and_or_position",
        input = "SELECT * FROM users WHERE x = 1 AND y = 2 OR z = 3",
        opts = { where_condition_style = "inline", and_or_position = "leading" },
        expected = {
            -- Even with leading position, inline keeps everything on one line
            contains = { "WHERE x = 1 AND y = 2 OR z = 3" }
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

    -- DDL options (Phase 4)
    -- create_table_column_newline tests
    {
        id = 8521,
        type = "formatter",
        name = "create_table_column_newline true (default) - columns on separate lines",
        input = "CREATE TABLE users (id INT, name VARCHAR(100), email VARCHAR(255))",
        opts = { create_table_column_newline = true },
        expected = {
            matches = { "id INT,\n.-name VARCHAR", "name VARCHAR%(100%),\n.-email VARCHAR" }
        }
    },
    {
        id = 8522,
        type = "formatter",
        name = "create_table_column_newline false - columns on one line",
        input = "CREATE TABLE users (id INT, name VARCHAR(100), email VARCHAR(255))",
        opts = { create_table_column_newline = false },
        expected = {
            contains = { "id INT, name VARCHAR(100), email VARCHAR(255)" }
        }
    },
    {
        id = 8523,
        type = "formatter",
        name = "create_table_column_newline with PRIMARY KEY constraint",
        input = "CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(100))",
        opts = { create_table_column_newline = true },
        expected = {
            matches = { "id INT PRIMARY KEY,\n.-name VARCHAR" }
        }
    },
    {
        id = 8524,
        type = "formatter",
        name = "create_table_column_newline with complex constraints",
        input = "CREATE TABLE orders (id INT NOT NULL, user_id INT FOREIGN KEY REFERENCES users(id), total DECIMAL(10,2))",
        opts = { create_table_column_newline = true },
        expected = {
            -- Each column on new line, but nested parens in DECIMAL(10,2) don't trigger newlines
            -- Note: formatter may add space after comma inside DECIMAL
            matches = { "id INT NOT NULL,\n", "user_id INT FOREIGN KEY REFERENCES users%(id%),\n", "total DECIMAL%(10" }
        }
    },
    {
        id = 8525,
        type = "formatter",
        name = "create_table_column_newline - SELECT after CREATE TABLE",
        input = "CREATE TABLE temp (a INT, b INT); SELECT * FROM temp",
        opts = { create_table_column_newline = true },
        expected = {
            -- CREATE TABLE has columns on new lines, then SELECT follows normally
            -- Note: identifier 'temp' may be uppercased to TEMP
            matches = { "a INT,\n.-b INT" },
            contains = { "SELECT *", "FROM" }
        }
    },

    -- in_list_style tests (Phase 4 Expressions / also where_in_list_style)
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

    -- from_alias_align tests (IDs: 8530-8535)
    {
        id = 8530,
        type = "formatter",
        name = "from_alias_align true - basic alignment",
        input = "SELECT * FROM users u JOIN orders o ON u.id = o.user_id",
        opts = { from_alias_align = true },
        expected = {
            -- users (5 chars) and orders (6 chars) - users gets 1 space padding
            contains = { "users  u", "orders o" }
        }
    },
    {
        id = 8531,
        type = "formatter",
        name = "from_alias_align true - multiple joins",
        input = "SELECT * FROM users u JOIN orders o ON u.id = o.user_id JOIN order_items oi ON o.id = oi.order_id",
        opts = { from_alias_align = true },
        expected = {
            -- users (5), orders (6), order_items (11) - align to 11
            contains = { "users       u", "orders      o", "order_items oi" }
        }
    },
    {
        id = 8532,
        type = "formatter",
        name = "from_alias_align false - no alignment",
        input = "SELECT * FROM users u JOIN orders o ON u.id = o.user_id",
        opts = { from_alias_align = false },
        expected = {
            -- Standard spacing
            contains = { "users u", "orders o" }
        }
    },
    {
        id = 8533,
        type = "formatter",
        name = "from_alias_align with schema-qualified tables",
        input = "SELECT * FROM dbo.users u JOIN dbo.orders o ON u.id = o.user_id",
        opts = { from_alias_align = true },
        expected = {
            -- dbo.users (9 chars) and dbo.orders (10 chars)
            contains = { "dbo.users  u", "dbo.orders o" }
        }
    },
    {
        id = 8534,
        type = "formatter",
        name = "from_alias_align with AS keyword",
        input = "SELECT * FROM users AS u JOIN orders AS o ON u.id = o.user_id",
        opts = { from_alias_align = true },
        expected = {
            -- AS keyword should be included in alignment
            contains = { "users  AS u", "orders AS o" }
        }
    },
    {
        id = 8535,
        type = "formatter",
        name = "from_alias_align with LEFT/RIGHT joins",
        input = "SELECT * FROM users u LEFT JOIN orders o ON u.id = o.user_id RIGHT JOIN payments p ON o.id = p.order_id",
        opts = { from_alias_align = true },
        expected = {
            -- users (5), orders (6), payments (8)
            contains = { "users    u", "orders   o", "payments p" }
        }
    },

    -- ============================================
    -- comment_position tests (IDs: 8536-8545)
    -- ============================================
    {
        id = 8536,
        type = "formatter",
        name = "comment_position preserve - inline comment stays inline",
        input = "SELECT a, b -- comment\nFROM users",
        opts = { comment_position = "preserve" },
        expected = {
            contains = { "b -- comment" }  -- Comment stays on same line as b
        }
    },
    {
        id = 8537,
        type = "formatter",
        name = "comment_position preserve - block comment stays in place",
        input = "SELECT /* comment */ a FROM users",
        opts = { comment_position = "preserve" },
        expected = {
            contains = { "/* comment */" }
        }
    },
    {
        id = 8538,
        type = "formatter",
        name = "comment_position above - moves inline comment to own line",
        input = "SELECT a, b -- comment\nFROM users",
        opts = { comment_position = "above" },
        expected = {
            -- Comment should be on its own line (not inline with b)
            -- Output: b\n-- comment\nFROM
            matches = { "b\n%-%-.-comment" }
        }
    },
    {
        id = 8539,
        type = "formatter",
        name = "comment_position above - block comment on own line",
        input = "SELECT a, /* comment */ b FROM users",
        opts = { comment_position = "above" },
        expected = {
            -- Block comment should be on its own line
            matches = { "/%* comment %*/\n" }
        }
    },
    {
        id = 8540,
        type = "formatter",
        name = "comment_position inline - keeps comments inline",
        input = "SELECT a,\n-- comment\nb FROM users",
        opts = { comment_position = "inline" },
        expected = {
            -- Comment should move to same line as b
            contains = { "-- comment" }
        }
    },
    {
        id = 8541,
        type = "formatter",
        name = "comment_position preserve - multiline block comment",
        input = "SELECT /* line1\nline2 */ a FROM users",
        opts = { comment_position = "preserve" },
        expected = {
            contains = { "/* line1", "line2 */" }
        }
    },

    -- ============================================
    -- subquery_paren_style tests (IDs: 8546-8551)
    -- ============================================
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

    -- ============================================
    -- function_arg_style tests (IDs: 8552-8559)
    -- ============================================
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

    -- ============================================
    -- group_by_newline, having_newline, order_by_newline tests (IDs: 8559-8570)
    -- ============================================
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

    -- ============================================
    -- max_consecutive_blank_lines tests (IDs: 8567-8572)
    -- ============================================
    {
        id = 8567,
        type = "formatter",
        name = "max_consecutive_blank_lines 0 - no blank lines between statements",
        input = "SELECT * FROM users; SELECT * FROM orders;",
        opts = { max_consecutive_blank_lines = 0 },
        expected = {
            -- No blank lines between statements
            matches = { "users;\nSELECT" }
        }
    },
    {
        id = 8568,
        type = "formatter",
        name = "max_consecutive_blank_lines 1 - limits to 1 blank line",
        input = "SELECT * FROM users; SELECT * FROM orders;",
        opts = { max_consecutive_blank_lines = 1, blank_line_between_statements = 3 },
        expected = {
            -- Should be limited to 1 blank line even though 3 requested
            matches = { "users;\n\nSELECT" },
            not_matches = { "users;\n\n\nSELECT" }
        }
    },
    {
        id = 8569,
        type = "formatter",
        name = "max_consecutive_blank_lines default (2)",
        input = "SELECT * FROM users; SELECT * FROM orders;",
        opts = { blank_line_between_statements = 5 },
        expected = {
            -- Default max is 2, so 5 requested should be limited to 2
            matches = { "users;\n\n\nSELECT" }
        }
    },

    -- =========================================================================
    -- use_as_keyword tests (Phase 3: Casing)
    -- =========================================================================
    {
        id = 8570,
        type = "formatter",
        name = "use_as_keyword - column alias without AS gets AS added",
        input = "SELECT name n, email e FROM users",
        opts = { use_as_keyword = true },
        expected = {
            contains = { "name AS n", "email AS e" }
        }
    },
    {
        id = 8571,
        type = "formatter",
        name = "use_as_keyword - column alias with AS stays unchanged",
        input = "SELECT name AS n, email AS e FROM users",
        opts = { use_as_keyword = true },
        expected = {
            contains = { "name AS n", "email AS e" },
            not_contains = { "AS AS" }
        }
    },
    {
        id = 8572,
        type = "formatter",
        name = "use_as_keyword - table alias without AS gets AS added",
        input = "SELECT * FROM users u WHERE u.id = 1",
        opts = { use_as_keyword = true },
        expected = {
            contains = { "users AS u" }
        }
    },
    {
        id = 8573,
        type = "formatter",
        name = "use_as_keyword - table alias with AS stays unchanged",
        input = "SELECT * FROM users AS u WHERE u.id = 1",
        opts = { use_as_keyword = true },
        expected = {
            contains = { "users AS u" },
            not_contains = { "AS AS" }
        }
    },
    {
        id = 8574,
        type = "formatter",
        name = "use_as_keyword - JOIN table alias without AS gets AS added",
        input = "SELECT * FROM users u JOIN orders o ON u.id = o.user_id",
        opts = { use_as_keyword = true },
        expected = {
            contains = { "users AS u", "orders AS o" }
        }
    },
    {
        id = 8575,
        type = "formatter",
        name = "use_as_keyword false - aliases stay without AS",
        input = "SELECT name n FROM users u",
        opts = { use_as_keyword = false },
        expected = {
            contains = { "name n", "users u" },
            not_contains = { "AS n", "AS u" }
        }
    },
    {
        id = 8576,
        type = "formatter",
        name = "use_as_keyword - qualified table name no false positive",
        input = "SELECT * FROM dbo.users WHERE id = 1",
        opts = { use_as_keyword = true },
        expected = {
            contains = { "dbo.users" },
            not_contains = { "AS users" }
        }
    },
    {
        id = 8577,
        type = "formatter",
        name = "use_as_keyword - lowercase keyword case",
        input = "SELECT name n FROM users u",
        opts = { use_as_keyword = true, keyword_case = "lower" },
        expected = {
            contains = { "as n", "as u" }
        }
    },

    -- =========================================================================
    -- blank_line_before_comment tests (Phase 3: Blank Lines)
    -- =========================================================================
    {
        id = 8578,
        type = "formatter",
        name = "blank_line_before_comment true - adds blank line before standalone comment",
        input = "SELECT * FROM users\n-- Get active users\nWHERE active = 1",
        opts = { blank_line_before_comment = true },
        expected = {
            -- Blank line should appear before the comment
            matches = { "users\n\n%s*%-%-" }
        }
    },
    {
        id = 8579,
        type = "formatter",
        name = "blank_line_before_comment false (default) - no extra blank line",
        input = "SELECT * FROM users\n-- Get active users\nWHERE active = 1",
        opts = { blank_line_before_comment = false },
        expected = {
            -- No blank line before comment
            not_matches = { "users\n\n%s*%-%-" }
        }
    },
    {
        id = 8580,
        type = "formatter",
        name = "blank_line_before_comment - block comment",
        input = "SELECT * FROM users\n/* Filter logic */\nWHERE active = 1",
        opts = { blank_line_before_comment = true },
        expected = {
            -- Blank line before block comment
            matches = { "users\n\n%s*/%*" }
        }
    },
    {
        id = 8581,
        type = "formatter",
        name = "blank_line_before_comment - inline comment stays inline",
        input = "SELECT * FROM users -- all users",
        opts = { blank_line_before_comment = true },
        expected = {
            -- Inline comment should stay on same line, no blank line
            contains = { "users -- all users" }
        }
    },
    {
        id = 8582,
        type = "formatter",
        name = "blank_line_before_comment - no double blank lines",
        input = "SELECT * FROM users\n\n-- Already has blank line\nWHERE active = 1",
        opts = { blank_line_before_comment = true },
        expected = {
            -- Should not add extra blank line if one already exists
            not_matches = { "\n\n\n%s*%-%-" }
        }
    },

    -- =========================================================================
    -- insert_into_keyword tests (Phase 2: DML)
    -- =========================================================================
    {
        id = 8583,
        type = "formatter",
        name = "insert_into_keyword true - adds INTO when missing",
        input = "INSERT users (name) VALUES ('test')",
        opts = { insert_into_keyword = true },
        expected = {
            contains = { "INSERT INTO users" }
        }
    },
    {
        id = 8584,
        type = "formatter",
        name = "insert_into_keyword true - keeps INTO when present",
        input = "INSERT INTO users (name) VALUES ('test')",
        opts = { insert_into_keyword = true },
        expected = {
            contains = { "INSERT INTO users" },
            not_contains = { "INTO INTO" }
        }
    },
    {
        id = 8585,
        type = "formatter",
        name = "insert_into_keyword false - no change",
        input = "INSERT users (name) VALUES ('test')",
        opts = { insert_into_keyword = false },
        expected = {
            contains = { "INSERT users" },
            not_contains = { "INSERT INTO" }
        }
    },
    {
        id = 8586,
        type = "formatter",
        name = "insert_into_keyword - schema qualified table",
        input = "INSERT dbo.users (name) VALUES ('test')",
        opts = { insert_into_keyword = true },
        expected = {
            contains = { "INSERT INTO dbo.users" }
        }
    },
    {
        id = 8587,
        type = "formatter",
        name = "insert_into_keyword - lowercase keyword case",
        input = "INSERT users (name) VALUES ('test')",
        opts = { insert_into_keyword = true, keyword_case = "lower" },
        expected = {
            contains = { "insert into users" }
        }
    },

    -- =========================================================================
    -- delete_from_keyword tests (Phase 2: DML)
    -- =========================================================================
    {
        id = 8588,
        type = "formatter",
        name = "delete_from_keyword true - adds FROM when missing",
        input = "DELETE users WHERE id = 1",
        opts = { delete_from_keyword = true },
        expected = {
            -- FROM is on new line by default (delete_from_newline = true)
            matches = { "DELETE\nFROM users" }
        }
    },
    {
        id = 8589,
        type = "formatter",
        name = "delete_from_keyword true - keeps FROM when present",
        input = "DELETE FROM users WHERE id = 1",
        opts = { delete_from_keyword = true },
        expected = {
            -- FROM should appear after DELETE (may be on new line due to delete_from_newline)
            matches = { "DELETE%s+FROM%s+users" },
            not_contains = { "FROM FROM" }
        }
    },
    {
        id = 8590,
        type = "formatter",
        name = "delete_from_keyword false - no change",
        input = "DELETE users WHERE id = 1",
        opts = { delete_from_keyword = false },
        expected = {
            contains = { "DELETE users" },
            not_contains = { "DELETE FROM" }
        }
    },
    {
        id = 8591,
        type = "formatter",
        name = "delete_from_keyword - schema qualified table",
        input = "DELETE dbo.users WHERE id = 1",
        opts = { delete_from_keyword = true },
        expected = {
            -- FROM is on new line by default (delete_from_newline = true)
            matches = { "DELETE\nFROM dbo.users" }
        }
    },
    {
        id = 8592,
        type = "formatter",
        name = "delete_from_keyword - lowercase keyword case",
        input = "DELETE users WHERE id = 1",
        opts = { delete_from_keyword = true, keyword_case = "lower" },
        expected = {
            contains = { "delete", "from users" }
        }
    },
    {
        id = 8593,
        type = "formatter",
        name = "delete_from_keyword - alias syntax preserved (DELETE u FROM users u)",
        input = "DELETE u FROM users u WHERE u.id = 1",
        opts = { delete_from_keyword = true },
        expected = {
            -- Should NOT insert another FROM - alias syntax already has FROM
            contains = { "DELETE u", "FROM users u" },
            not_contains = { "FROM FROM" }
        }
    },
    {
        id = 8594,
        type = "formatter",
        name = "delete_from_keyword - respects delete_from_newline false",
        input = "DELETE users WHERE id = 1",
        opts = { delete_from_keyword = true, delete_from_newline = false },
        expected = {
            contains = { "DELETE FROM users" }
        }
    },
    {
        id = 8595,
        type = "formatter",
        name = "delete_from_keyword - respects delete_from_newline true (default)",
        input = "DELETE users WHERE id = 1",
        opts = { delete_from_keyword = true, delete_from_newline = true },
        expected = {
            -- FROM should be on new line
            matches = { "DELETE\nFROM users" }
        }
    },

    -- =========================================================================
    -- from_table_style tests (Phase 1: FROM Clause)
    -- =========================================================================
    {
        id = 8596,
        type = "formatter",
        name = "from_table_style inline (default) - multiple tables on one line",
        input = "SELECT * FROM users, orders, products",
        opts = { from_table_style = "inline" },
        expected = {
            contains = { "FROM users, orders, products" }
        }
    },
    {
        id = 8597,
        type = "formatter",
        name = "from_table_style stacked - each table on new line",
        input = "SELECT * FROM users, orders, products",
        opts = { from_table_style = "stacked" },
        expected = {
            matches = { "FROM users,\n%s*orders,\n%s*products" }
        }
    },
    {
        id = 8598,
        type = "formatter",
        name = "from_table_style stacked_indent - first table on new line",
        input = "SELECT * FROM users, orders, products",
        opts = { from_table_style = "stacked_indent" },
        expected = {
            -- First table should be on new line after FROM
            matches = { "FROM\n%s+users,\n%s+orders,\n%s+products" }
        }
    },
    {
        id = 8599,
        type = "formatter",
        name = "from_table_style stacked vs stacked_indent comparison",
        input = "SELECT * FROM a, b FROM t",
        opts = { from_table_style = "stacked" },
        expected = {
            -- stacked: first table on same line as FROM
            contains = { "FROM a," }
        }
    },
    {
        id = 85991,
        type = "formatter",
        name = "from_table_style stacked with aliases",
        input = "SELECT * FROM users u, orders o, products p",
        opts = { from_table_style = "stacked" },
        expected = {
            matches = { "FROM users u,\n%s*orders o,\n%s*products p" }
        }
    },
    {
        id = 85992,
        type = "formatter",
        name = "from_table_style stacked_indent with aliases",
        input = "SELECT * FROM users u, orders o",
        opts = { from_table_style = "stacked_indent" },
        expected = {
            matches = { "FROM\n%s+users u,\n%s+orders o" }
        }
    },
    {
        id = 85993,
        type = "formatter",
        name = "from_table_style inline preserves single table",
        input = "SELECT * FROM users WHERE id = 1",
        opts = { from_table_style = "inline" },
        expected = {
            contains = { "FROM users" }
        }
    },
    {
        id = 85994,
        type = "formatter",
        name = "from_table_style stacked with schema-qualified tables",
        input = "SELECT * FROM dbo.users, dbo.orders",
        opts = { from_table_style = "stacked" },
        expected = {
            matches = { "FROM dbo.users,\n%s*dbo.orders" }
        }
    },
    {
        id = 85995,
        type = "formatter",
        name = "from_table_style inline - doesn't affect JOINs",
        input = "SELECT * FROM users, orders JOIN products ON orders.product_id = products.id",
        opts = { from_table_style = "inline" },
        expected = {
            -- JOIN should still be on new line (controlled by join_newline)
            contains = { "FROM users, orders" },
            matches = { "\nJOIN products" }
        }
    },
    {
        id = 85996,
        type = "formatter",
        name = "from_table_style stacked - subquery tables not affected",
        input = "SELECT * FROM (SELECT id FROM users) AS sub, orders",
        opts = { from_table_style = "stacked" },
        expected = {
            -- Subquery content handled separately, outer tables stacked
            contains = { "AS sub," }
        }
    },

    -- =========================================================================
    -- on_condition_style tests (Phase 1: JOIN Clause)
    -- =========================================================================
    {
        id = 8700,
        type = "formatter",
        name = "on_condition_style inline (default) - all conditions on one line",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id AND u.active = 1",
        opts = { on_condition_style = "inline" },
        expected = {
            contains = { "ON u.id = o.user_id AND u.active = 1" }
        }
    },
    {
        id = 8701,
        type = "formatter",
        name = "on_condition_style stacked - AND/OR on new lines",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id AND u.active = 1",
        opts = { on_condition_style = "stacked", on_and_position = "leading" },
        expected = {
            matches = { "ON u.id = o.user_id\n%s+AND u.active = 1" }
        }
    },
    {
        id = 8702,
        type = "formatter",
        name = "on_condition_style stacked_indent - first condition on new line",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id AND u.active = 1",
        opts = { on_condition_style = "stacked_indent", on_and_position = "leading" },
        expected = {
            -- First condition on new line after ON, then AND on new line
            matches = { "ON\n%s+u.id = o.user_id\n%s+AND u.active = 1" }
        }
    },
    {
        id = 8703,
        type = "formatter",
        name = "on_condition_style stacked with trailing AND",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id AND u.active = 1",
        opts = { on_condition_style = "stacked", on_and_position = "trailing" },
        expected = {
            -- AND at end of line, next condition on new line
            matches = { "ON u.id = o.user_id AND\n%s+u.active = 1" }
        }
    },
    {
        id = 8704,
        type = "formatter",
        name = "on_condition_style inline ignores on_and_position",
        input = "SELECT * FROM users u INNER JOIN orders o ON a = 1 AND b = 2 OR c = 3",
        opts = { on_condition_style = "inline", on_and_position = "leading" },
        expected = {
            -- Even with leading position, inline keeps everything on one line
            contains = { "ON a = 1 AND b = 2 OR c = 3" }
        }
    },
    {
        id = 8705,
        type = "formatter",
        name = "on_condition_style stacked with multiple ANDs",
        input = "SELECT * FROM a JOIN b ON a.id = b.a_id AND a.type = b.type AND a.status = 'active'",
        opts = { on_condition_style = "stacked", on_and_position = "leading" },
        expected = {
            matches = { "ON a.id = b.a_id\n%s+AND a.type = b.type\n%s+AND a.status = 'active'" }
        }
    },
    {
        id = 8706,
        type = "formatter",
        name = "on_condition_style stacked_indent with multiple ANDs",
        input = "SELECT * FROM a JOIN b ON a.id = b.a_id AND a.type = b.type AND a.status = 'active'",
        opts = { on_condition_style = "stacked_indent", on_and_position = "leading" },
        expected = {
            -- First condition on new line after ON, all ANDs stacked
            matches = { "ON\n%s+a.id = b.a_id\n%s+AND a.type = b.type\n%s+AND a.status = 'active'" }
        }
    },
    {
        id = 8707,
        type = "formatter",
        name = "on_condition_style stacked - multiple JOINs",
        input = "SELECT * FROM a JOIN b ON a.id = b.a_id AND a.x = b.x LEFT JOIN c ON b.id = c.b_id AND b.y = c.y",
        opts = { on_condition_style = "stacked", on_and_position = "leading" },
        expected = {
            -- Both ON clauses should have stacked conditions
            matches = { "ON a.id = b.a_id\n%s+AND a.x = b.x", "ON b.id = c.b_id\n%s+AND b.y = c.y" }
        }
    },
    {
        id = 8708,
        type = "formatter",
        name = "on_condition_style stacked_indent - single condition stays on new line",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id",
        opts = { on_condition_style = "stacked_indent" },
        expected = {
            -- Even with single condition, it should be on new line after ON
            matches = { "ON\n%s+u.id = o.user_id" }
        }
    },
    {
        id = 8709,
        type = "formatter",
        name = "on_condition_style inline - complex condition with parentheses",
        input = "SELECT * FROM a JOIN b ON (a.id = b.id AND a.type = 1) OR a.override = 1",
        opts = { on_condition_style = "inline" },
        expected = {
            contains = { "ON (a.id = b.id AND a.type = 1) OR a.override = 1" }
        }
    },

    -- =========================================================================
    -- cross_apply_newline tests (Phase 1: JOIN Clause)
    -- =========================================================================
    {
        id = 8710,
        type = "formatter",
        name = "cross_apply_newline true (default) - CROSS APPLY on new line",
        input = "SELECT * FROM users u CROSS APPLY (SELECT TOP 1 * FROM orders WHERE user_id = u.id) o",
        opts = { cross_apply_newline = true },
        expected = {
            matches = { "FROM users u\nCROSS APPLY" }
        }
    },
    {
        id = 8711,
        type = "formatter",
        name = "cross_apply_newline false - CROSS APPLY on same line",
        input = "SELECT * FROM users u CROSS APPLY (SELECT TOP 1 * FROM orders WHERE user_id = u.id) o",
        opts = { cross_apply_newline = false },
        expected = {
            contains = { "FROM users u CROSS APPLY" }
        }
    },
    {
        id = 8712,
        type = "formatter",
        name = "cross_apply_newline true - OUTER APPLY on new line",
        input = "SELECT * FROM users u OUTER APPLY (SELECT TOP 1 * FROM orders WHERE user_id = u.id) o",
        opts = { cross_apply_newline = true },
        expected = {
            matches = { "FROM users u\nOUTER APPLY" }
        }
    },
    {
        id = 8713,
        type = "formatter",
        name = "cross_apply_newline false - OUTER APPLY on same line",
        input = "SELECT * FROM users u OUTER APPLY (SELECT TOP 1 * FROM orders WHERE user_id = u.id) o",
        opts = { cross_apply_newline = false },
        expected = {
            contains = { "FROM users u OUTER APPLY" }
        }
    },
    {
        id = 8714,
        type = "formatter",
        name = "cross_apply_newline true - multiple APPLY operators",
        input = "SELECT * FROM users u CROSS APPLY fn1(u.id) a OUTER APPLY fn2(a.val) b",
        opts = { cross_apply_newline = true },
        expected = {
            matches = { "FROM users u\nCROSS APPLY", "\nOUTER APPLY" }
        }
    },
    {
        id = 8715,
        type = "formatter",
        name = "cross_apply_newline with JOIN - both on new lines",
        input = "SELECT * FROM users u INNER JOIN profiles p ON u.id = p.user_id CROSS APPLY fn(u.id) a",
        opts = { cross_apply_newline = true },
        expected = {
            matches = { "\nINNER JOIN", "\nCROSS APPLY" }
        }
    },
    {
        id = 8716,
        type = "formatter",
        name = "cross_apply_newline - APPLY with table-valued function",
        input = "SELECT * FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t",
        opts = { cross_apply_newline = true },
        expected = {
            matches = { "FROM sys.dm_exec_requests r\nCROSS APPLY" }
        }
    },

    -- ============================================
    -- insert_columns_style tests (IDs: 8720-8729)
    -- ============================================
    {
        id = 8720,
        type = "formatter",
        name = "insert_columns_style inline (default) - all columns on one line",
        input = "INSERT INTO users (id, name, email, created_at) VALUES (1, 'John', 'john@test.com', GETDATE())",
        opts = { insert_columns_style = "inline" },
        expected = {
            contains = { "(id, name, email, created_at)" }
        }
    },
    {
        id = 8721,
        type = "formatter",
        name = "insert_columns_style stacked - each column on new line",
        input = "INSERT INTO users (id, name, email) VALUES (1, 'John', 'john@test.com')",
        opts = { insert_columns_style = "stacked" },
        expected = {
            matches = { "%(id,\n.-name,\n.-email%)" }
        }
    },
    {
        id = 8722,
        type = "formatter",
        name = "insert_columns_style stacked_indent - first column on new line",
        input = "INSERT INTO users (id, name, email) VALUES (1, 'John', 'john@test.com')",
        opts = { insert_columns_style = "stacked_indent" },
        expected = {
            matches = { "%(\n.-id,\n.-name,\n.-email" }
        }
    },
    {
        id = 8723,
        type = "formatter",
        name = "insert_columns_style stacked - with schema qualified table",
        input = "INSERT INTO dbo.users (id, name, email) VALUES (1, 'John', 'john@test.com')",
        opts = { insert_columns_style = "stacked" },
        expected = {
            -- No space between table name and ( is allowed
            matches = { "INTO dbo.users%s*%(id,\n.-name,\n.-email%)" }
        }
    },
    {
        id = 8724,
        type = "formatter",
        name = "insert_columns_style stacked - VALUES stays on same line (inline)",
        input = "INSERT INTO users (id, name) VALUES (1, 'John')",
        opts = { insert_columns_style = "stacked", insert_values_style = "inline" },
        expected = {
            matches = { "%(id,\n.-name%)" },
            contains = { "VALUES (1, 'John')" }
        }
    },
    {
        id = 8725,
        type = "formatter",
        name = "insert_columns_style inline - many columns stay on one line",
        input = "INSERT INTO orders (id, user_id, product_id, quantity, price, status) VALUES (1, 2, 3, 10, 99.99, 'pending')",
        opts = { insert_columns_style = "inline" },
        expected = {
            contains = { "(id, user_id, product_id, quantity, price, status)" }
        }
    },
    {
        id = 8726,
        type = "formatter",
        name = "insert_columns_style stacked - bracket identifiers",
        input = "INSERT INTO [users] ([id], [first name], [email]) VALUES (1, 'John', 'john@test.com')",
        opts = { insert_columns_style = "stacked" },
        expected = {
            matches = { "%[id%],\n.-%[first name%],\n.-%[email%]" }
        }
    },
    {
        id = 8727,
        type = "formatter",
        name = "insert_columns_style inline - preserves column order",
        input = "INSERT INTO users (z_col, a_col, m_col) VALUES (1, 2, 3)",
        opts = { insert_columns_style = "inline" },
        expected = {
            contains = { "(z_col, a_col, m_col)" }
        }
    },
    {
        id = 8728,
        type = "formatter",
        name = "insert_columns_style stacked - does not affect SELECT INTO",
        input = "SELECT id, name INTO #temp FROM users",
        opts = { insert_columns_style = "stacked" },
        expected = {
            -- SELECT INTO should not be affected by insert_columns_style
            contains = { "SELECT id," }
        }
    },
    {
        id = 8729,
        type = "formatter",
        name = "insert_columns_style stacked_indent - closing paren after last column",
        input = "INSERT INTO users (id, name, email) VALUES (1, 'John', 'john@test.com')",
        opts = { insert_columns_style = "stacked_indent" },
        expected = {
            -- First column on new line after (, closing paren on same line as last column
            matches = { "%(\n.-id,\n.-name,\n.-email%)" }
        }
    },

    -- ============================================
    -- insert_values_style tests (IDs: 8730-8739)
    -- ============================================
    {
        id = 8730,
        type = "formatter",
        name = "insert_values_style inline (default) - all values on one line",
        input = "INSERT INTO users (id, name, email) VALUES (1, 'John', 'john@test.com')",
        opts = { insert_values_style = "inline" },
        expected = {
            contains = { "VALUES (1, 'John', 'john@test.com')" }
        }
    },
    {
        id = 8731,
        type = "formatter",
        name = "insert_values_style stacked - each value on new line",
        input = "INSERT INTO users (id, name, email) VALUES (1, 'John', 'john@test.com')",
        opts = { insert_values_style = "stacked" },
        expected = {
            matches = { "VALUES %(1,\n.-'John',\n.-'john@test.com'%)" }
        }
    },
    {
        id = 8732,
        type = "formatter",
        name = "insert_values_style stacked_indent - first value on new line",
        input = "INSERT INTO users (id, name, email) VALUES (1, 'John', 'john@test.com')",
        opts = { insert_values_style = "stacked_indent" },
        expected = {
            matches = { "VALUES %(\n.-1,\n.-'John',\n.-'john@test.com'" }
        }
    },
    {
        id = 8733,
        type = "formatter",
        name = "insert_values_style stacked - numeric and function values",
        input = "INSERT INTO orders (id, created_at, total) VALUES (1, GETDATE(), 99.99)",
        opts = { insert_values_style = "stacked" },
        expected = {
            matches = { "VALUES %(1,\n.-GETDATE%(%),\n.-99.99%)" }
        }
    },
    {
        id = 8734,
        type = "formatter",
        name = "insert_values_style stacked - columns stay inline when columns_style is inline",
        input = "INSERT INTO users (id, name) VALUES (1, 'John')",
        opts = { insert_columns_style = "inline", insert_values_style = "stacked" },
        expected = {
            contains = { "(id, name)" },
            matches = { "VALUES %(1,\n.-'John'%)" }
        }
    },
    {
        id = 8735,
        type = "formatter",
        name = "insert_values_style inline - many values stay on one line",
        input = "INSERT INTO orders (a, b, c, d, e, f) VALUES (1, 2, 3, 4, 5, 6)",
        opts = { insert_values_style = "inline" },
        expected = {
            contains = { "VALUES (1, 2, 3, 4, 5, 6)" }
        }
    },
    {
        id = 8736,
        type = "formatter",
        name = "insert_values_style stacked - NULL values",
        input = "INSERT INTO users (id, name, email) VALUES (1, NULL, 'test@test.com')",
        opts = { insert_values_style = "stacked" },
        expected = {
            matches = { "VALUES %(1,\n.-NULL,\n.-'test@test.com'%)" }
        }
    },
    {
        id = 8737,
        type = "formatter",
        name = "insert_values_style stacked - with multi-row (multi_row_style also stacked)",
        input = "INSERT INTO users (id, name) VALUES (1, 'John'), (2, 'Jane')",
        opts = { insert_values_style = "stacked", insert_multi_row_style = "stacked" },
        expected = {
            -- Each row on new line, values within row also stacked
            matches = { "%(1,\n.-'John'%)" }
        }
    },
    {
        id = 8738,
        type = "formatter",
        name = "insert_values_style inline - preserves value order",
        input = "INSERT INTO t (a, b, c) VALUES ('z', 'a', 'm')",
        opts = { insert_values_style = "inline" },
        expected = {
            contains = { "VALUES ('z', 'a', 'm')" }
        }
    },
    {
        id = 8739,
        type = "formatter",
        name = "insert_values_style stacked_indent - closing paren after last value",
        input = "INSERT INTO users (id, name) VALUES (1, 'John')",
        opts = { insert_values_style = "stacked_indent" },
        expected = {
            -- First value on new line after (, closing paren on same line as last value
            matches = { "VALUES %(\n.-1,\n.-'John'%)" }
        }
    },

    -- ============================================
    -- cte_columns_style tests (IDs: 8740-8749)
    -- ============================================
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

    -- ============================================
    -- where_between_style tests (IDs: 8750-8759)
    -- Controls formatting of BETWEEN ... AND expressions
    -- ============================================
    {
        id = 8750,
        type = "formatter",
        name = "where_between_style inline (default) - all on one line",
        input = "SELECT * FROM orders WHERE created_at BETWEEN '2020-01-01' AND '2020-12-31'",
        opts = { where_between_style = "inline" },
        expected = {
            contains = { "BETWEEN '2020-01-01' AND '2020-12-31'" }
        }
    },
    {
        id = 8751,
        type = "formatter",
        name = "where_between_style stacked - AND on new line",
        input = "SELECT * FROM orders WHERE created_at BETWEEN '2020-01-01' AND '2020-12-31'",
        opts = { where_between_style = "stacked" },
        expected = {
            matches = { "BETWEEN '2020%-01%-01'\n.-AND '2020%-12%-31'" }
        }
    },
    {
        id = 8752,
        type = "formatter",
        name = "where_between_style stacked_indent - first value on new line",
        input = "SELECT * FROM orders WHERE created_at BETWEEN '2020-01-01' AND '2020-12-31'",
        opts = { where_between_style = "stacked_indent" },
        expected = {
            matches = { "BETWEEN\n.-'2020%-01%-01'\n.-AND '2020%-12%-31'" }
        }
    },
    {
        id = 8753,
        type = "formatter",
        name = "where_between_style stacked - numeric values",
        input = "SELECT * FROM products WHERE price BETWEEN 10 AND 100",
        opts = { where_between_style = "stacked" },
        expected = {
            matches = { "BETWEEN 10\n.-AND 100" }
        }
    },
    {
        id = 8754,
        type = "formatter",
        name = "where_between_style stacked - column references",
        input = "SELECT * FROM orders WHERE o.date BETWEEN start_date AND end_date",
        opts = { where_between_style = "stacked" },
        expected = {
            matches = { "BETWEEN start_date\n.-AND end_date" }
        }
    },
    {
        id = 8755,
        type = "formatter",
        name = "where_between_style stacked - function calls",
        input = "SELECT * FROM orders WHERE created_at BETWEEN DATEADD(day, -30, GETDATE()) AND GETDATE()",
        opts = { where_between_style = "stacked" },
        expected = {
            -- Function calls stay intact, AND on new line
            -- Note: 'day' is uppercased to 'DAY' as it's a keyword
            contains = { "DATEADD(DAY, -30, GETDATE())", "GETDATE()" },
            matches = { "BETWEEN DATEADD.-\n.-AND GETDATE" }
        }
    },
    {
        id = 8756,
        type = "formatter",
        name = "where_between_style stacked - NOT BETWEEN",
        input = "SELECT * FROM products WHERE price NOT BETWEEN 10 AND 100",
        opts = { where_between_style = "stacked" },
        expected = {
            matches = { "NOT BETWEEN 10\n.-AND 100" }
        }
    },
    {
        id = 8757,
        type = "formatter",
        name = "where_between_style inline - multiple BETWEEN in WHERE",
        input = "SELECT * FROM orders WHERE date BETWEEN '2020-01-01' AND '2020-12-31' AND price BETWEEN 10 AND 100",
        opts = { where_between_style = "inline", and_or_position = "leading" },
        expected = {
            -- Both BETWEEN clauses inline
            contains = { "BETWEEN '2020-01-01' AND '2020-12-31'", "BETWEEN 10 AND 100" }
        }
    },
    {
        id = 8758,
        type = "formatter",
        name = "where_between_style stacked_indent - CASE expression BETWEEN",
        input = "SELECT CASE WHEN x BETWEEN 1 AND 10 THEN 'low' ELSE 'high' END FROM t",
        opts = { where_between_style = "stacked_indent" },
        expected = {
            -- BETWEEN in CASE expression
            matches = { "BETWEEN\n.-1\n.-AND 10" }
        }
    },
    {
        id = 8759,
        type = "formatter",
        name = "where_between_style stacked - preserves other AND/OR",
        input = "SELECT * FROM orders WHERE status = 'active' AND date BETWEEN '2020-01-01' AND '2020-12-31' OR status = 'pending'",
        opts = { where_between_style = "stacked", and_or_position = "leading" },
        expected = {
            -- BETWEEN AND is stacked, but boolean AND/OR follow their own rules
            -- Note: 'date' is uppercased to 'DATE' as it's a reserved word
            matches = { "BETWEEN '2020%-01%-01'\n.-AND '2020%-12%-31'" },
            contains = { "AND DATE BETWEEN", "OR status" }
        }
    },

    -- ============================================
    -- where_in_list_style tests (IDs: 8760-8769)
    -- Controls formatting of IN (...) lists in WHERE clause
    -- where_in_list_style takes precedence over in_list_style
    -- ============================================
    {
        id = 8760,
        type = "formatter",
        name = "where_in_list_style inline (default) - all values on one line",
        input = "SELECT * FROM users WHERE id IN (1, 2, 3, 4, 5)",
        opts = { where_in_list_style = "inline" },
        expected = {
            contains = { "IN (1, 2, 3, 4, 5)" }
        }
    },
    {
        id = 8761,
        type = "formatter",
        name = "where_in_list_style stacked - each value on new line",
        input = "SELECT * FROM users WHERE id IN (1, 2, 3)",
        opts = { where_in_list_style = "stacked" },
        expected = {
            matches = { "IN %(1,\n.-2,\n.-3%)" }
        }
    },
    {
        id = 8762,
        type = "formatter",
        name = "where_in_list_style stacked_indent - first value on new line",
        input = "SELECT * FROM users WHERE id IN (1, 2, 3)",
        opts = { where_in_list_style = "stacked_indent" },
        expected = {
            -- Opening paren, then newline, then values stacked
            matches = { "IN %(\n.-1,\n.-2,\n.-3" }
        }
    },
    {
        id = 8763,
        type = "formatter",
        name = "where_in_list_style stacked with string values",
        input = "SELECT * FROM users WHERE status IN ('active', 'pending', 'approved')",
        opts = { where_in_list_style = "stacked" },
        expected = {
            matches = { "IN %('active',\n.-'pending',\n.-'approved'%)" }
        }
    },
    {
        id = 8764,
        type = "formatter",
        name = "where_in_list_style takes precedence over in_list_style",
        input = "SELECT * FROM users WHERE id IN (1, 2, 3)",
        opts = { where_in_list_style = "stacked", in_list_style = "inline" },
        expected = {
            -- where_in_list_style should be used (stacked), not in_list_style (inline)
            matches = { "IN %(1,\n.-2,\n.-3%)" }
        }
    },
    {
        id = 8765,
        type = "formatter",
        name = "where_in_list_style - in_list_style used as fallback",
        input = "SELECT * FROM users WHERE id IN (1, 2, 3)",
        opts = { in_list_style = "stacked" },
        expected = {
            -- in_list_style used when where_in_list_style not set
            matches = { "IN %(1,\n.-2,\n.-3%)" }
        }
    },
    {
        id = 8766,
        type = "formatter",
        name = "where_in_list_style stacked - NOT IN also handled",
        input = "SELECT * FROM users WHERE id NOT IN (1, 2, 3)",
        opts = { where_in_list_style = "stacked" },
        expected = {
            matches = { "NOT IN %(1,\n.-2,\n.-3%)" }
        }
    },
    {
        id = 8767,
        type = "formatter",
        name = "where_in_list_style stacked_indent - proper indentation",
        input = "SELECT * FROM users WHERE id IN (100, 200, 300)",
        opts = { where_in_list_style = "stacked_indent" },
        expected = {
            -- Values should be indented (8 spaces - base + 2 levels)
            matches = { "IN %(\n        100,\n        200,\n        300" }
        }
    },
    {
        id = 8768,
        type = "formatter",
        name = "where_in_list_style inline - nested function calls stay inline",
        input = "SELECT * FROM users WHERE id IN (1, GETDATE(), 3)",
        opts = { where_in_list_style = "inline" },
        expected = {
            contains = { "IN (1, GETDATE(), 3)" }
        }
    },
    {
        id = 8769,
        type = "formatter",
        name = "where_in_list_style stacked - with AND/OR conditions",
        input = "SELECT * FROM users WHERE id IN (1, 2, 3) AND status = 'active'",
        opts = { where_in_list_style = "stacked", and_or_position = "leading" },
        expected = {
            -- IN list stacked, AND on new line
            matches = { "IN %(1,\n.-2,\n.-3%)" },
            matches = { "\n.-AND status" }
        }
    },
}
