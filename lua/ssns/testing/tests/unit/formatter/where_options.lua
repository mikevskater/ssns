-- Test file: where_options.lua
-- IDs: 84691-84694, 8470-8478, 8750-8769
-- Tests: WHERE clause options - where_newline, condition_style, between_style, in_list_style

return {
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

    -- where_between_style tests
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

    -- where_in_list_style tests
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
            not_matches = { "\n.-AND status" }
        }
    },
}
