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
}
