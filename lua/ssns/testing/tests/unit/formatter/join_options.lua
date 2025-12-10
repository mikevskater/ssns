-- Test file: join_options.lua
-- IDs: 8460-8465, 84651-846592, 8700-8716, 9070-9080
-- Tests: JOIN clause options - empty_line_before_join, join_keyword_style, on_condition_style, cross_apply, join_indent_style

return {
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

    -- on_condition_style tests
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

    -- cross_apply_newline tests
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

    -- join_indent_style tests
    {
        id = 9070,
        type = "formatter",
        name = "join_indent_style indent (default) - JOIN indented from FROM",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id",
        opts = { join_indent_style = "indent" },
        expected = {
            -- JOIN should be indented (4 spaces from FROM level)
            matches = { "FROM users u\n    INNER JOIN orders o" }
        }
    },
    {
        id = 9071,
        type = "formatter",
        name = "join_indent_style align - JOIN aligns with FROM",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id",
        opts = { join_indent_style = "align" },
        expected = {
            -- JOIN should be at same level as FROM (no indent)
            matches = { "FROM users u\nINNER JOIN orders o" }
        }
    },
    {
        id = 9072,
        type = "formatter",
        name = "join_indent_style indent - ON clause further indented",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id",
        opts = { join_indent_style = "indent", join_on_same_line = false },
        expected = {
            -- ON should be indented from JOIN (2 levels from base)
            matches = { "INNER JOIN orders o\n        ON u.id" }
        }
    },
    {
        id = 9073,
        type = "formatter",
        name = "join_indent_style align - ON clause indented from JOIN",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id",
        opts = { join_indent_style = "align", join_on_same_line = false },
        expected = {
            -- ON should be indented from JOIN (1 level from base)
            matches = { "INNER JOIN orders o\n    ON u.id" }
        }
    },
    {
        id = 9074,
        type = "formatter",
        name = "join_indent_style indent - multiple JOINs all indented",
        input = "SELECT * FROM a INNER JOIN b ON a.id = b.a_id LEFT JOIN c ON b.id = c.b_id",
        opts = { join_indent_style = "indent" },
        expected = {
            -- All JOINs should be indented from FROM level
            matches = { "FROM a\n    INNER JOIN b", "\n    LEFT JOIN c" }
        }
    },
    {
        id = 9075,
        type = "formatter",
        name = "join_indent_style align - multiple JOINs all aligned",
        input = "SELECT * FROM a INNER JOIN b ON a.id = b.a_id LEFT JOIN c ON b.id = c.b_id",
        opts = { join_indent_style = "align" },
        expected = {
            -- All JOINs should be at same level as FROM
            matches = { "FROM a\nINNER JOIN b", "\nLEFT JOIN c" }
        }
    },
    {
        id = 9076,
        type = "formatter",
        name = "join_indent_style indent - with empty_line_before_join",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id",
        opts = { join_indent_style = "indent", empty_line_before_join = true },
        expected = {
            -- Empty line AND indentation
            matches = { "FROM users u\n\n    INNER JOIN orders o" }
        }
    },
    {
        id = 9077,
        type = "formatter",
        name = "join_indent_style align - with empty_line_before_join",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id",
        opts = { join_indent_style = "align", empty_line_before_join = true },
        expected = {
            -- Empty line but no indentation
            matches = { "FROM users u\n\nINNER JOIN orders o" }
        }
    },
    {
        id = 9078,
        type = "formatter",
        name = "join_indent_style indent - standalone JOIN (no modifier)",
        input = "SELECT * FROM users u JOIN orders o ON u.id = o.user_id",
        opts = { join_indent_style = "indent" },
        expected = {
            matches = { "FROM users u\n    JOIN orders o" }
        }
    },
    {
        id = 9079,
        type = "formatter",
        name = "join_indent_style indent - CROSS APPLY also indented",
        input = "SELECT * FROM users u CROSS APPLY fn(u.id) a",
        opts = { join_indent_style = "indent", cross_apply_newline = true },
        expected = {
            matches = { "FROM users u\n    CROSS APPLY fn" }
        }
    },
    {
        id = 9080,
        type = "formatter",
        name = "join_indent_style align - CROSS APPLY aligns with FROM",
        input = "SELECT * FROM users u CROSS APPLY fn(u.id) a",
        opts = { join_indent_style = "align", cross_apply_newline = true },
        expected = {
            matches = { "FROM users u\nCROSS APPLY fn" }
        }
    },
}
