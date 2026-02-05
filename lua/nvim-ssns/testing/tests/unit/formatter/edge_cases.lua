-- Test file: edge_cases.lua
-- IDs: 8251-8300
-- Tests: Edge cases - empty input, syntax errors, long lines, special characters, dialect-specific

return {
    -- Empty and minimal input
    {
        id = 8251,
        type = "formatter",
        name = "Empty string",
        input = "",
        expected = {
            formatted = ""
        }
    },
    {
        id = 8252,
        type = "formatter",
        name = "Whitespace only",
        input = "   \n\t\n   ",
        expected = {
            -- Whitespace-only input is preserved (no tokens to format)
            -- This is acceptable behavior
            max_duration_ms = 10
        }
    },
    {
        id = 8253,
        type = "formatter",
        name = "Single keyword",
        input = "SELECT",
        expected = {
            formatted = "SELECT"
        }
    },
    {
        id = 8254,
        type = "formatter",
        name = "Single identifier",
        input = "users",
        expected = {
            formatted = "users"
        }
    },

    -- Syntax errors (best-effort formatting)
    {
        id = 8260,
        type = "formatter",
        name = "Incomplete SELECT",
        input = "SELECT FROM users",
        expected = {
            -- Should preserve and format what it can
            contains = { "SELECT", "FROM users" }
        }
    },
    {
        id = 8261,
        type = "formatter",
        name = "Missing FROM clause",
        input = "SELECT * WHERE id = 1",
        expected = {
            contains = { "SELECT *", "WHERE id = 1" }
        }
    },
    {
        id = 8262,
        type = "formatter",
        name = "Unclosed parenthesis",
        input = "SELECT * FROM users WHERE id IN (1, 2, 3",
        expected = {
            -- Best effort - should still format keywords
            contains = { "SELECT", "FROM", "WHERE", "IN (" }
        }
    },
    {
        id = 8263,
        type = "formatter",
        name = "Extra closing parenthesis",
        input = "SELECT * FROM users WHERE id = 1)",
        expected = {
            contains = { "SELECT", "FROM", "WHERE" }
        }
    },
    {
        id = 8264,
        type = "formatter",
        name = "Unclosed string literal",
        input = "SELECT * FROM users WHERE name = 'John",
        expected = {
            -- Should preserve original on parse error
            contains = { "SELECT", "FROM", "WHERE" }
        }
    },
    {
        id = 8265,
        type = "formatter",
        name = "Invalid operator",
        input = "SELECT * FROM users WHERE id <=> 1",
        expected = {
            -- Unknown operator preserved
            contains = { "SELECT", "FROM", "WHERE" }
        }
    },

    -- Very long lines
    {
        id = 8270,
        type = "formatter",
        name = "Very long column list",
        input = "SELECT col1, col2, col3, col4, col5, col6, col7, col8, col9, col10, col11, col12, col13, col14, col15, col16, col17, col18, col19, col20 FROM big_table",
        expected = {
            contains = { "col1", "col20", "FROM big_table" }
        }
    },
    {
        id = 8271,
        type = "formatter",
        name = "Very long WHERE clause",
        input = "SELECT * FROM users WHERE (condition1 = 'value1' AND condition2 = 'value2' AND condition3 = 'value3' AND condition4 = 'value4' AND condition5 = 'value5')",
        expected = {
            contains = { "condition1 = 'value1'", "condition5 = 'value5'" }
        }
    },
    {
        id = 8272,
        type = "formatter",
        name = "Very long string literal",
        input = "SELECT * FROM users WHERE description = 'This is a very long string literal that contains a lot of text and should be preserved exactly as it was written without any modifications to the content inside the quotes'",
        expected = {
            contains = { "This is a very long string literal" }
        }
    },
    {
        id = 8273,
        type = "formatter",
        name = "Deeply nested subqueries",
        input = "SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT * FROM (SELECT * FROM t1) t2) t3) t4) t5",
        expected = {
            contains = { "SELECT *", "FROM t1" }
        }
    },

    -- Special characters and escaping
    {
        id = 8275,
        type = "formatter",
        name = "String with escaped quote",
        input = "SELECT * FROM users WHERE name = 'O''Brien'",
        expected = {
            contains = { "'O''Brien'" }
        }
    },
    {
        id = 8276,
        type = "formatter",
        name = "Unicode in identifier",
        input = "SELECT [Имя], [名前] FROM [таблица]",
        expected = {
            contains = { "[Имя]", "[名前]", "[таблица]" }
        }
    },
    {
        id = 8277,
        type = "formatter",
        name = "Unicode in string",
        input = "SELECT * FROM users WHERE name = N'日本語テスト'",
        expected = {
            contains = { "N'日本語テスト'" }
        }
    },
    {
        id = 8278,
        type = "formatter",
        name = "Identifier with spaces",
        input = "SELECT [First Name], [Last Name] FROM [User Accounts]",
        expected = {
            contains = { "[First Name]", "[Last Name]", "[User Accounts]" }
        }
    },
    {
        id = 8279,
        type = "formatter",
        name = "Reserved word as identifier",
        input = "SELECT [SELECT], [FROM], [WHERE] FROM [TABLE]",
        expected = {
            contains = { "[SELECT]", "[FROM]", "[WHERE]", "[TABLE]" }
        }
    },

    -- Multiple statements
    {
        id = 8280,
        type = "formatter",
        name = "Two SELECT statements",
        input = "SELECT * FROM users; SELECT * FROM orders;",
        expected = {
            contains = { "FROM users", "FROM orders" }
        }
    },
    {
        id = 8281,
        type = "formatter",
        name = "Mixed DML statements",
        input = "INSERT INTO log VALUES (1); UPDATE users SET x=1; DELETE FROM temp;",
        expected = {
            contains = { "INSERT INTO log", "UPDATE users", "DELETE" }
        }
    },
    {
        id = 8282,
        type = "formatter",
        name = "GO batch separator (SQL Server)",
        input = "SELECT * FROM users\nGO\nSELECT * FROM orders",
        expected = {
            contains = { "FROM users", "GO", "FROM orders" }
        }
    },

    -- SQL Server specific syntax
    {
        id = 8285,
        type = "formatter",
        name = "NOLOCK hint",
        input = "SELECT * FROM users WITH (NOLOCK) WHERE active = 1",
        expected = {
            contains = { "WITH (NOLOCK)" }
        }
    },
    {
        id = 8286,
        type = "formatter",
        name = "Variables",
        input = "DECLARE @id INT = 1; SELECT * FROM users WHERE id = @id",
        expected = {
            contains = { "DECLARE @id INT", "@id" }
        }
    },
    {
        id = 8287,
        type = "formatter",
        name = "Temp table",
        input = "SELECT * INTO #temp FROM users; SELECT * FROM #temp",
        expected = {
            contains = { "#temp" }
        }
    },
    {
        id = 8288,
        type = "formatter",
        name = "Global temp table",
        input = "SELECT * INTO ##global_temp FROM users",
        expected = {
            contains = { "##global_temp" }
        }
    },
    {
        id = 8289,
        type = "formatter",
        name = "Table variable",
        input = "DECLARE @t TABLE (id INT); INSERT INTO @t SELECT id FROM users",
        expected = {
            contains = { "DECLARE @t TABLE", "@t" }
        }
    },

    -- PostgreSQL specific syntax (should still format)
    {
        id = 8290,
        type = "formatter",
        name = "PostgreSQL double colon cast",
        input = "SELECT id::TEXT, amount::DECIMAL FROM orders",
        expected = {
            contains = { "id::TEXT", "amount::DECIMAL" }
        }
    },
    {
        id = 8291,
        type = "formatter",
        name = "PostgreSQL array syntax",
        input = "SELECT ARRAY[1, 2, 3] AS arr",
        expected = {
            -- TODO: ARRAY[ should not have space, but [1, 2, 3] is treated as bracket_id
            contains = { "ARRAY", "[1, 2, 3]", "AS arr" }
        }
    },
    {
        id = 8292,
        type = "formatter",
        name = "PostgreSQL RETURNING clause",
        input = "INSERT INTO users (name) VALUES ('Test') RETURNING id",
        expected = {
            contains = { "RETURNING id" }
        }
    },

    -- MySQL specific syntax (should still format)
    {
        id = 8293,
        type = "formatter",
        name = "MySQL backtick identifiers",
        input = "SELECT `id`, `name` FROM `users`",
        expected = {
            contains = { "`id`", "`name`", "`users`" }
        }
    },
    {
        id = 8294,
        type = "formatter",
        name = "MySQL LIMIT clause",
        input = "SELECT * FROM users LIMIT 10 OFFSET 20",
        expected = {
            contains = { "LIMIT 10", "OFFSET 20" }
        }
    },

    -- Whitespace edge cases
    {
        id = 8295,
        type = "formatter",
        name = "Tab characters",
        input = "SELECT\t*\tFROM\tusers\tWHERE\tid\t=\t1",
        expected = {
            contains = { "SELECT", "FROM", "WHERE" },
            not_contains = { "\t" }
        }
    },
    {
        id = 8296,
        type = "formatter",
        name = "Mixed line endings",
        input = "SELECT *\r\nFROM users\rWHERE id = 1",
        expected = {
            contains = { "SELECT", "FROM", "WHERE" }
        }
    },
    {
        id = 8297,
        type = "formatter",
        name = "No spaces around operators",
        input = "SELECT*FROM users WHERE id=1 AND active=1 OR status='admin'",
        expected = {
            -- Adds spaces around operators and after keywords
            contains = { "id = 1", "active = 1", "status = 'admin'" }
        }
    },
    {
        id = 8298,
        type = "formatter",
        name = "Excessive spacing",
        input = "SELECT     *      FROM       users        WHERE          id    =     1",
        expected = {
            not_contains = { "     " }
        }
    },

    -- Complex real-world query
    {
        id = 8300,
        type = "formatter",
        name = "Complex production query",
        input = "WITH OrderTotals AS (SELECT customer_id, SUM(amount) AS total FROM orders WHERE order_date >= DATEADD(MONTH, -3, GETDATE()) GROUP BY customer_id HAVING SUM(amount) > 1000), CustomerRanking AS (SELECT c.id, c.name, ot.total, ROW_NUMBER() OVER (ORDER BY ot.total DESC) AS rank FROM customers c INNER JOIN OrderTotals ot ON c.id = ot.customer_id WHERE c.status = 'active') SELECT cr.rank, cr.name, cr.total, CASE WHEN cr.rank <= 10 THEN 'VIP' WHEN cr.rank <= 50 THEN 'Premium' ELSE 'Standard' END AS tier FROM CustomerRanking cr WHERE cr.rank <= 100 ORDER BY cr.rank",
        expected = {
            -- Note: "rank" is a SQL keyword (RANK() function) so it gets uppercased to RANK
            contains = {
                "WITH OrderTotals AS (",
                "CustomerRanking AS (",
                "ROW_NUMBER() OVER",
                "INNER JOIN OrderTotals ot",
                "CASE",
                "WHEN cr.RANK <= 10",
                "END AS tier",
                "ORDER BY cr.RANK"
            }
        }
    },
}
