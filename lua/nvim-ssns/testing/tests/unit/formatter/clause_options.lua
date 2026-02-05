-- Test file: clause_options.lua
-- IDs: 8950-8990, 8720-8739
-- Tests: Miscellaneous clause options - max_consecutive_blank_lines, use_as_keyword,
--        blank_line_before_comment, insert_into_keyword, delete_from_keyword,
--        insert_columns_style, insert_values_style

return {
    -- ============================================
    -- max_consecutive_blank_lines tests (IDs: 8950-8952)
    -- ============================================
    {
        id = 8950,
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
        id = 8951,
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
        id = 8952,
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
    -- use_as_keyword tests (IDs: 8953-8960)
    -- =========================================================================
    {
        id = 8953,
        type = "formatter",
        name = "use_as_keyword - column alias without AS gets AS added",
        input = "SELECT name n, email e FROM users",
        opts = { use_as_keyword = true },
        expected = {
            contains = { "name AS n", "email AS e" }
        }
    },
    {
        id = 8954,
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
        id = 8955,
        type = "formatter",
        name = "use_as_keyword - table alias without AS gets AS added",
        input = "SELECT * FROM users u WHERE u.id = 1",
        opts = { use_as_keyword = true },
        expected = {
            contains = { "users AS u" }
        }
    },
    {
        id = 8956,
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
        id = 8957,
        type = "formatter",
        name = "use_as_keyword - JOIN table alias without AS gets AS added",
        input = "SELECT * FROM users u JOIN orders o ON u.id = o.user_id",
        opts = { use_as_keyword = true },
        expected = {
            contains = { "users AS u", "orders AS o" }
        }
    },
    {
        id = 8958,
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
        id = 8959,
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
        id = 8960,
        type = "formatter",
        name = "use_as_keyword - lowercase keyword case",
        input = "SELECT name n FROM users u",
        opts = { use_as_keyword = true, keyword_case = "lower" },
        expected = {
            contains = { "as n", "as u" }
        }
    },

    -- =========================================================================
    -- blank_line_before_comment tests (IDs: 8961-8965)
    -- =========================================================================
    {
        id = 8961,
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
        id = 8962,
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
        id = 8963,
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
        id = 8964,
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
        id = 8965,
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
    -- insert_into_keyword tests (IDs: 8970-8974)
    -- =========================================================================
    {
        id = 8970,
        type = "formatter",
        name = "insert_into_keyword true - adds INTO when missing",
        input = "INSERT users (name) VALUES ('test')",
        opts = { insert_into_keyword = true },
        expected = {
            contains = { "INSERT INTO users" }
        }
    },
    {
        id = 8971,
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
        id = 8972,
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
        id = 8973,
        type = "formatter",
        name = "insert_into_keyword - schema qualified table",
        input = "INSERT dbo.users (name) VALUES ('test')",
        opts = { insert_into_keyword = true },
        expected = {
            contains = { "INSERT INTO dbo.users" }
        }
    },
    {
        id = 8974,
        type = "formatter",
        name = "insert_into_keyword - lowercase keyword case",
        input = "INSERT users (name) VALUES ('test')",
        opts = { insert_into_keyword = true, keyword_case = "lower" },
        expected = {
            contains = { "insert into users" }
        }
    },

    -- =========================================================================
    -- delete_from_keyword tests (IDs: 8980-8988)
    -- =========================================================================
    {
        id = 8980,
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
        id = 8981,
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
        id = 8982,
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
        id = 8983,
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
        id = 8984,
        type = "formatter",
        name = "delete_from_keyword - lowercase keyword case",
        input = "DELETE users WHERE id = 1",
        opts = { delete_from_keyword = true, keyword_case = "lower" },
        expected = {
            contains = { "delete", "from users" }
        }
    },
    {
        id = 8985,
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
        id = 8986,
        type = "formatter",
        name = "delete_from_keyword - respects delete_from_newline false",
        input = "DELETE users WHERE id = 1",
        opts = { delete_from_keyword = true, delete_from_newline = false },
        expected = {
            contains = { "DELETE FROM users" }
        }
    },
    {
        id = 8987,
        type = "formatter",
        name = "delete_from_keyword - respects delete_from_newline true (default)",
        input = "DELETE users WHERE id = 1",
        opts = { delete_from_keyword = true, delete_from_newline = true },
        expected = {
            -- FROM should be on new line
            matches = { "DELETE\nFROM users" }
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
}
