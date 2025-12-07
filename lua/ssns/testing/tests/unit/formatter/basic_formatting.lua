-- Test file: basic_formatting.lua
-- IDs: 8001-8050
-- Tests: Basic SQL formatting - keyword casing, whitespace normalization

return {
    -- Keyword casing tests (default: uppercase)
    {
        id = 8001,
        type = "formatter",
        name = "Uppercase SELECT keyword",
        input = "select * from users",
        expected = {
            contains = { "SELECT" },
            not_contains = { "select" }
        }
    },
    {
        id = 8002,
        type = "formatter",
        name = "Uppercase FROM keyword",
        input = "select * from users",
        expected = {
            contains = { "FROM" },
            not_contains = { "from" }
        }
    },
    {
        id = 8003,
        type = "formatter",
        name = "Uppercase WHERE keyword",
        input = "select * from users where id = 1",
        expected = {
            contains = { "WHERE" },
            not_contains = { "where" }
        }
    },
    {
        id = 8004,
        type = "formatter",
        name = "Uppercase all keywords in simple query",
        input = "select id, name from users where active = 1",
        expected = {
            contains = { "SELECT", "FROM", "WHERE" },
            not_contains = { "select", "from", "where" }
        }
    },
    {
        id = 8005,
        type = "formatter",
        name = "Preserve identifier case",
        input = "select UserName, EmailAddress from Users",
        expected = {
            contains = { "UserName", "EmailAddress", "Users" }
        }
    },

    -- Whitespace normalization tests
    {
        id = 8010,
        type = "formatter",
        name = "Normalize multiple spaces",
        input = "SELECT    *    FROM    users",
        expected = {
            not_contains = { "    " }
        }
    },
    {
        id = 8011,
        type = "formatter",
        name = "Normalize tabs to spaces",
        input = "SELECT\t*\tFROM\tusers",
        expected = {
            not_contains = { "\t" }
        }
    },
    {
        id = 8012,
        type = "formatter",
        name = "Space around equals operator",
        input = "SELECT * FROM users WHERE id=1",
        expected = {
            contains = { "id = 1" }
        }
    },
    {
        id = 8013,
        type = "formatter",
        name = "Space around comparison operators",
        input = "SELECT * FROM users WHERE age>18 AND salary<100000",
        expected = {
            contains = { "age > 18", "salary < 100000" }
        }
    },

    -- Newline before major clauses
    {
        id = 8020,
        type = "formatter",
        name = "Newline before FROM clause",
        input = "SELECT * FROM users",
        expected = {
            formatted = "SELECT *\nFROM users"
        }
    },
    {
        id = 8021,
        type = "formatter",
        name = "Newline before WHERE clause",
        input = "SELECT * FROM users WHERE id = 1",
        expected = {
            formatted = "SELECT *\nFROM users\nWHERE id = 1"
        }
    },
    {
        id = 8022,
        type = "formatter",
        name = "Newlines before all major clauses",
        input = "SELECT id, name FROM users WHERE active = 1 ORDER BY name",
        expected = {
            -- Columns on separate lines with trailing comma (SSMS style)
            contains = { "SELECT id,", "name", "FROM users", "WHERE active = 1", "ORDER BY name" }
        }
    },

    -- Parenthesis handling
    {
        id = 8030,
        type = "formatter",
        name = "No space inside parentheses",
        input = "SELECT COUNT( * ) FROM users",
        expected = {
            contains = { "COUNT(*)" }
        }
    },
    {
        id = 8031,
        type = "formatter",
        name = "Function call formatting",
        input = "SELECT UPPER(name), LOWER(email) FROM users",
        expected = {
            contains = { "UPPER(name)", "LOWER(email)" }
        }
    },
    {
        id = 8032,
        type = "formatter",
        name = "Nested function calls",
        input = "SELECT COALESCE(NULLIF(name,''),default_name) FROM users",
        expected = {
            contains = { "COALESCE(NULLIF(name, ''), default_name)" }
        }
    },

    -- String literal preservation
    {
        id = 8040,
        type = "formatter",
        name = "Preserve single-quoted strings",
        input = "SELECT * FROM users WHERE name = 'John Doe'",
        expected = {
            contains = { "'John Doe'" }
        }
    },
    {
        id = 8041,
        type = "formatter",
        name = "Preserve string with special chars",
        input = "SELECT * FROM users WHERE email LIKE '%@example.com'",
        expected = {
            contains = { "'%@example.com'" }
        }
    },
    {
        id = 8042,
        type = "formatter",
        name = "Preserve empty string",
        input = "SELECT * FROM users WHERE name <> ''",
        expected = {
            contains = { "<> ''" }
        }
    },

    -- Number formatting
    {
        id = 8045,
        type = "formatter",
        name = "Integer literals",
        input = "SELECT * FROM users WHERE id = 123",
        expected = {
            contains = { "123" }
        }
    },
    {
        id = 8046,
        type = "formatter",
        name = "Decimal literals",
        input = "SELECT * FROM products WHERE price > 99.99",
        expected = {
            contains = { "99.99" }
        }
    },
    {
        id = 8047,
        type = "formatter",
        name = "Negative numbers",
        input = "SELECT * FROM accounts WHERE balance < -1000",
        expected = {
            contains = { "-1000" }
        }
    },

    -- Basic identifier types
    {
        id = 8048,
        type = "formatter",
        name = "Bracketed identifiers",
        input = "SELECT [First Name], [Last Name] FROM [User Table]",
        expected = {
            contains = { "[First Name]", "[Last Name]", "[User Table]" }
        }
    },
    {
        id = 8049,
        type = "formatter",
        name = "Qualified names with schema",
        input = "SELECT * FROM dbo.Users",
        expected = {
            contains = { "dbo.Users" }
        }
    },
    {
        id = 8050,
        type = "formatter",
        name = "Three-part names",
        input = "SELECT * FROM Database.dbo.Users",
        expected = {
            contains = { "Database.dbo.Users" }
        }
    },
}
