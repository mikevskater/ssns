-- Test file: production_queries.lua
-- IDs: 1701-1750
-- Tests: Production-style tokenization edge cases

return {
    -- IDs 1701-1710: Complex String Patterns
    {
        id = 1701,
        type = "tokenizer",
        name = "String with escaped single quotes",
        input = "SELECT 'It''s a test'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "'It''s a test'" }
        }
    },
    {
        id = 1702,
        type = "tokenizer",
        name = "Unicode string with N prefix",
        input = "SELECT N'Hello World'",
        expected = {
            -- N prefix is now included in the string token
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "N'Hello World'" }
        }
    },
    {
        id = 1703,
        type = "tokenizer",
        name = "Multi-line string literal",
        input = "SELECT 'Line 1\nLine 2\nLine 3'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "'Line 1\nLine 2\nLine 3'" }
        }
    },
    {
        id = 1704,
        type = "tokenizer",
        name = "Empty string literal",
        input = "SELECT ''",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "''" }
        }
    },
    {
        id = 1705,
        type = "tokenizer",
        name = "String containing SQL keywords",
        input = "SELECT 'SELECT * FROM Users WHERE id = 1'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "'SELECT * FROM Users WHERE id = 1'" }
        }
    },
    {
        id = 1706,
        type = "tokenizer",
        name = "String with numbers and operators",
        input = "SELECT '123 + 456 = 579'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "'123 + 456 = 579'" }
        }
    },
    {
        id = 1707,
        type = "tokenizer",
        name = "String with special characters",
        input = "SELECT 'Email: user@example.com, Phone: (555) 123-4567'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "'Email: user@example.com, Phone: (555) 123-4567'" }
        }
    },
    {
        id = 1708,
        type = "tokenizer",
        name = "Multiple strings in query",
        input = "SELECT 'First', 'Second', 'Third'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "'First'" },
            { type = "comma", text = "," },
            { type = "string", text = "'Second'" },
            { type = "comma", text = "," },
            { type = "string", text = "'Third'" }
        }
    },
    {
        id = 1709,
        type = "tokenizer",
        name = "Unicode string with escaped quotes",
        input = "SELECT N'It''s unicode'",
        expected = {
            -- N prefix is included in the string token
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "N'It''s unicode'" }
        }
    },
    {
        id = 1710,
        type = "tokenizer",
        name = "String with backslashes",
        input = "SELECT 'C:\\Windows\\System32\\config'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "'C:\\Windows\\System32\\config'" }
        }
    },

    -- IDs 1711-1720: Comment Patterns (comments now emitted as tokens)
    {
        id = 1711,
        type = "tokenizer",
        name = "Single line comment at end",
        input = "SELECT * FROM Users -- Get all users",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" },
            { type = "line_comment", text = "-- Get all users" }
        }
    },
    {
        id = 1712,
        type = "tokenizer",
        name = "Block comment between keywords",
        input = "SELECT /* comment */ * FROM Users",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "comment", text = "/* comment */" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" }
        }
    },
    {
        id = 1713,
        type = "tokenizer",
        name = "Multi-line block comment",
        input = "SELECT /*\n  Multi-line\n  comment\n*/ * FROM Users",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "comment", text = "/*\n  Multi-line\n  comment\n*/" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" }
        }
    },
    {
        id = 1714,
        type = "tokenizer",
        name = "Comment containing string",
        input = "SELECT * FROM Users -- WHERE name = 'John'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" },
            { type = "line_comment", text = "-- WHERE name = 'John'" }
        }
    },
    {
        id = 1715,
        type = "tokenizer",
        name = "Comment containing code",
        input = "SELECT id, name /* , email, phone */ FROM Users",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "identifier", text = "id" },
            { type = "comma", text = "," },
            { type = "identifier", text = "name" },
            { type = "comment", text = "/* , email, phone */" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" }
        }
    },
    {
        id = 1716,
        type = "tokenizer",
        name = "Multiple single-line comments",
        input = "SELECT * -- comment 1\nFROM Users -- comment 2",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "line_comment", text = "-- comment 1" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" },
            { type = "line_comment", text = "-- comment 2" }
        }
    },
    {
        id = 1717,
        type = "tokenizer",
        name = "Block comment at start",
        input = "/* Header comment */ SELECT * FROM Users",
        expected = {
            { type = "comment", text = "/* Header comment */" },
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" }
        }
    },
    {
        id = 1718,
        type = "tokenizer",
        name = "Comment with special characters",
        input = "SELECT * FROM Users -- TODO: Fix this @bug #123",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" },
            { type = "line_comment", text = "-- TODO: Fix this @bug #123" }
        }
    },
    {
        id = 1719,
        type = "tokenizer",
        name = "Multiple block comments",
        input = "SELECT /* c1 */ * /* c2 */ FROM /* c3 */ Users",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "comment", text = "/* c1 */" },
            { type = "star", text = "*" },
            { type = "comment", text = "/* c2 */" },
            { type = "keyword", text = "FROM" },
            { type = "comment", text = "/* c3 */" },
            { type = "identifier", text = "Users" }
        }
    },
    {
        id = 1720,
        type = "tokenizer",
        name = "Mixed comment styles",
        input = "/* Block */ SELECT * FROM Users -- Line",
        expected = {
            { type = "comment", text = "/* Block */" },
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" },
            { type = "line_comment", text = "-- Line" }
        }
    },

    -- IDs 1721-1730: Bracketed Identifier Patterns
    {
        id = 1721,
        type = "tokenizer",
        name = "Simple bracketed identifier",
        input = "SELECT [TableName]",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "bracket_id", text = "[TableName]" }
        }
    },
    {
        id = 1722,
        type = "tokenizer",
        name = "Bracketed identifier with spaces",
        input = "SELECT * FROM [My Table]",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "bracket_id", text = "[My Table]" }
        }
    },
    {
        id = 1723,
        type = "tokenizer",
        name = "Bracketed identifier with special characters",
        input = "SELECT [Table.Name@2024]",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "bracket_id", text = "[Table.Name@2024]" }
        }
    },
    {
        id = 1724,
        type = "tokenizer",
        name = "Schema and table both bracketed",
        input = "SELECT * FROM [dbo].[Users]",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "bracket_id", text = "[dbo]" },
            { type = "dot", text = "." },
            { type = "bracket_id", text = "[Users]" }
        }
    },
    {
        id = 1725,
        type = "tokenizer",
        name = "Bracketed reserved word as identifier",
        input = "SELECT [SELECT] FROM [FROM]",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "bracket_id", text = "[SELECT]" },
            { type = "keyword", text = "FROM" },
            { type = "bracket_id", text = "[FROM]" }
        }
    },
    {
        id = 1726,
        type = "tokenizer",
        name = "Bracketed identifier with numbers",
        input = "SELECT [Column123] FROM [Table456]",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "bracket_id", text = "[Column123]" },
            { type = "keyword", text = "FROM" },
            { type = "bracket_id", text = "[Table456]" }
        }
    },
    {
        id = 1727,
        type = "tokenizer",
        name = "Bracketed identifier with hyphens",
        input = "SELECT * FROM [User-Accounts]",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "bracket_id", text = "[User-Accounts]" }
        }
    },
    {
        id = 1728,
        type = "tokenizer",
        name = "Fully qualified bracketed name",
        input = "SELECT [Server].[Database].[Schema].[Table]",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "bracket_id", text = "[Server]" },
            { type = "dot", text = "." },
            { type = "bracket_id", text = "[Database]" },
            { type = "dot", text = "." },
            { type = "bracket_id", text = "[Schema]" },
            { type = "dot", text = "." },
            { type = "bracket_id", text = "[Table]" }
        }
    },
    {
        id = 1729,
        type = "tokenizer",
        name = "Bracketed identifier in JOIN",
        input = "SELECT * FROM Users JOIN [User Details] ON Users.id = [User Details].user_id",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" },
            { type = "keyword", text = "JOIN" },
            { type = "bracket_id", text = "[User Details]" },
            { type = "keyword", text = "ON" },
            { type = "identifier", text = "Users" },
            { type = "dot", text = "." },
            { type = "identifier", text = "id" },
            { type = "operator", text = "=" },
            { type = "bracket_id", text = "[User Details]" },
            { type = "dot", text = "." },
            { type = "identifier", text = "user_id" }
        }
    },
    {
        id = 1730,
        type = "tokenizer",
        name = "Bracketed identifier with underscore",
        input = "SELECT [First_Name], [Last_Name]",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "bracket_id", text = "[First_Name]" },
            { type = "comma", text = "," },
            { type = "bracket_id", text = "[Last_Name]" }
        }
    },

    -- IDs 1731-1740: Operator and Special Character Patterns (multi-char operators now single tokens)
    {
        id = 1731,
        type = "tokenizer",
        name = "Multiple comparison operators",
        input = "WHERE a <= 5 AND b >= 10 AND c <> 0",
        expected = {
            { type = "keyword", text = "WHERE" },
            { type = "identifier", text = "a" },
            { type = "operator", text = "<=" },
            { type = "number", text = "5" },
            { type = "keyword", text = "AND" },
            { type = "identifier", text = "b" },
            { type = "operator", text = ">=" },
            { type = "number", text = "10" },
            { type = "keyword", text = "AND" },
            { type = "identifier", text = "c" },
            { type = "operator", text = "<>" },
            { type = "number", text = "0" }
        }
    },
    {
        id = 1732,
        type = "tokenizer",
        name = "String concatenation operator",
        input = "SELECT FirstName + ' ' + LastName",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "identifier", text = "FirstName" },
            { type = "operator", text = "+" },
            { type = "string", text = "' '" },
            { type = "operator", text = "+" },
            { type = "identifier", text = "LastName" }
        }
    },
    {
        id = 1733,
        type = "tokenizer",
        name = "Bitwise operators",
        input = "SELECT a & b, c | d, e ^ f, ~g",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "identifier", text = "a" },
            { type = "operator", text = "&" },
            { type = "identifier", text = "b" },
            { type = "comma", text = "," },
            { type = "identifier", text = "c" },
            { type = "operator", text = "|" },
            { type = "identifier", text = "d" },
            { type = "comma", text = "," },
            { type = "identifier", text = "e" },
            { type = "operator", text = "^" },
            { type = "identifier", text = "f" },
            { type = "comma", text = "," },
            { type = "operator", text = "~" },
            { type = "identifier", text = "g" }
        }
    },
    {
        id = 1734,
        type = "tokenizer",
        name = "Assignment operators",
        input = "SET @counter += 1",
        expected = {
            { type = "keyword", text = "SET" },
            { type = "variable", text = "@counter" },
            -- Compound assignment operators are separate tokens
            { type = "operator", text = "+" },
            { type = "operator", text = "=" },
            { type = "number", text = "1" }
        }
    },
    {
        id = 1735,
        type = "tokenizer",
        name = "Mathematical expression",
        input = "SELECT (a + b) * c / d - e",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "paren_open", text = "(" },
            { type = "identifier", text = "a" },
            { type = "operator", text = "+" },
            { type = "identifier", text = "b" },
            { type = "paren_close", text = ")" },
            { type = "star", text = "*" },
            { type = "identifier", text = "c" },
            { type = "operator", text = "/" },
            { type = "identifier", text = "d" },
            { type = "operator", text = "-" },
            { type = "identifier", text = "e" }
        }
    },
    {
        id = 1736,
        type = "tokenizer",
        name = "IS NULL and IS NOT NULL",
        input = "WHERE a IS NULL AND b IS NOT NULL",
        expected = {
            { type = "keyword", text = "WHERE" },
            { type = "identifier", text = "a" },
            { type = "keyword", text = "IS" },
            { type = "keyword", text = "NULL" },
            { type = "keyword", text = "AND" },
            { type = "identifier", text = "b" },
            { type = "keyword", text = "IS" },
            { type = "keyword", text = "NOT" },
            { type = "keyword", text = "NULL" }
        }
    },
    {
        id = 1737,
        type = "tokenizer",
        name = "Not equal operators both styles",
        input = "WHERE a <> 0 AND b != 0",
        expected = {
            { type = "keyword", text = "WHERE" },
            { type = "identifier", text = "a" },
            { type = "operator", text = "<>" },
            { type = "number", text = "0" },
            { type = "keyword", text = "AND" },
            { type = "identifier", text = "b" },
            { type = "operator", text = "!=" },
            { type = "number", text = "0" }
        }
    },
    {
        id = 1738,
        type = "tokenizer",
        name = "Compound assignment operators",
        input = "SET @a += 1, @b -= 2, @c *= 3, @d /= 4",
        expected = {
            -- Compound assignment operators are separate tokens
            { type = "keyword", text = "SET" },
            { type = "variable", text = "@a" },
            { type = "operator", text = "+" },
            { type = "operator", text = "=" },
            { type = "number", text = "1" },
            { type = "comma", text = "," },
            { type = "variable", text = "@b" },
            { type = "operator", text = "-" },
            { type = "operator", text = "=" },
            { type = "number", text = "2" },
            { type = "comma", text = "," },
            { type = "variable", text = "@c" },
            { type = "star", text = "*" },
            { type = "operator", text = "=" },
            { type = "number", text = "3" },
            { type = "comma", text = "," },
            { type = "variable", text = "@d" },
            { type = "operator", text = "/" },
            { type = "operator", text = "=" },
            { type = "number", text = "4" }
        }
    },
    {
        id = 1739,
        type = "tokenizer",
        name = "Modulo operator",
        input = "SELECT id % 2",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "identifier", text = "id" },
            { type = "operator", text = "%" },
            { type = "number", text = "2" }
        }
    },
    {
        id = 1740,
        type = "tokenizer",
        name = "Negative number",
        input = "SELECT -100",
        expected = {
            -- Negative numbers are now single tokens
            { type = "keyword", text = "SELECT" },
            { type = "number", text = "-100" }
        }
    },

    -- IDs 1741-1750: Production Query Tokenization
    {
        id = 1741,
        type = "tokenizer",
        name = "Variable and temp table references",
        input = "SELECT @UserId FROM #TempUsers",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "variable", text = "@UserId" },
            { type = "keyword", text = "FROM" },
            { type = "temp_table", text = "#TempUsers" }
        }
    },
    {
        id = 1742,
        type = "tokenizer",
        name = "SELECT with multiple columns",
        input = "SELECT id, name, email, phone FROM Users",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "identifier", text = "id" },
            { type = "comma", text = "," },
            { type = "identifier", text = "name" },
            { type = "comma", text = "," },
            { type = "identifier", text = "email" },
            { type = "comma", text = "," },
            { type = "identifier", text = "phone" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" }
        }
    },
    {
        id = 1743,
        type = "tokenizer",
        name = "INNER JOIN with ON clause",
        input = "SELECT * FROM Users JOIN Orders ON Users.id = Orders.user_id",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" },
            { type = "keyword", text = "JOIN" },
            { type = "identifier", text = "Orders" },
            { type = "keyword", text = "ON" },
            { type = "identifier", text = "Users" },
            { type = "dot", text = "." },
            { type = "identifier", text = "id" },
            { type = "operator", text = "=" },
            { type = "identifier", text = "Orders" },
            { type = "dot", text = "." },
            { type = "identifier", text = "user_id" }
        }
    },
    {
        id = 1744,
        type = "tokenizer",
        name = "WHERE with multiple conditions",
        input = "WHERE age >= 18 AND status = 'active' AND city = 'New York'",
        expected = {
            { type = "keyword", text = "WHERE" },
            { type = "identifier", text = "age" },
            { type = "operator", text = ">=" },
            { type = "number", text = "18" },
            { type = "keyword", text = "AND" },
            { type = "identifier", text = "status" },
            { type = "operator", text = "=" },
            { type = "string", text = "'active'" },
            { type = "keyword", text = "AND" },
            { type = "identifier", text = "city" },
            { type = "operator", text = "=" },
            { type = "string", text = "'New York'" }
        }
    },
    {
        id = 1745,
        type = "tokenizer",
        name = "GROUP BY with HAVING",
        input = "SELECT category, COUNT(*) FROM Products GROUP BY category HAVING COUNT(*) > 5",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "identifier", text = "category" },
            { type = "comma", text = "," },
            { type = "keyword", text = "COUNT" },
            { type = "paren_open", text = "(" },
            { type = "star", text = "*" },
            { type = "paren_close", text = ")" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Products" },
            { type = "keyword", text = "GROUP" },
            { type = "keyword", text = "BY" },
            { type = "identifier", text = "category" },
            { type = "keyword", text = "HAVING" },
            { type = "keyword", text = "COUNT" },
            { type = "paren_open", text = "(" },
            { type = "star", text = "*" },
            { type = "paren_close", text = ")" },
            { type = "operator", text = ">" },
            { type = "number", text = "5" }
        }
    },
    {
        id = 1746,
        type = "tokenizer",
        name = "Subquery in WHERE clause",
        input = "SELECT * FROM Users WHERE id IN (SELECT user_id FROM Orders)",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" },
            { type = "keyword", text = "WHERE" },
            { type = "identifier", text = "id" },
            { type = "keyword", text = "IN" },
            { type = "paren_open", text = "(" },
            { type = "keyword", text = "SELECT" },
            { type = "identifier", text = "user_id" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Orders" },
            { type = "paren_close", text = ")" }
        }
    },
    {
        id = 1747,
        type = "tokenizer",
        name = "CTE definition",
        input = "WITH ActiveUsers AS (SELECT * FROM Users WHERE active = 1) SELECT * FROM ActiveUsers",
        expected = {
            { type = "keyword", text = "WITH" },
            { type = "identifier", text = "ActiveUsers" },
            { type = "keyword", text = "AS" },
            { type = "paren_open", text = "(" },
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" },
            { type = "keyword", text = "WHERE" },
            { type = "identifier", text = "active" },
            { type = "operator", text = "=" },
            { type = "number", text = "1" },
            { type = "paren_close", text = ")" },
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "ActiveUsers" }
        }
    },
    {
        id = 1748,
        type = "tokenizer",
        name = "EXEC stored procedure with parameters",
        input = "EXEC GetUserById @UserId = 123",
        expected = {
            { type = "keyword", text = "EXEC" },
            { type = "identifier", text = "GetUserById" },
            { type = "variable", text = "@UserId" },
            { type = "operator", text = "=" },
            { type = "number", text = "123" }
        }
    },
    {
        id = 1749,
        type = "tokenizer",
        name = "DECLARE variables",
        input = "DECLARE @StartDate DATE, @EndDate DATE",
        expected = {
            { type = "keyword", text = "DECLARE" },
            { type = "variable", text = "@StartDate" },
            { type = "keyword", text = "DATE" },
            { type = "comma", text = "," },
            { type = "variable", text = "@EndDate" },
            { type = "keyword", text = "DATE" }
        }
    },
    {
        id = 1750,
        type = "tokenizer",
        name = "ORDER BY with ASC and DESC",
        input = "SELECT * FROM Users ORDER BY created_date DESC, name ASC",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" },
            { type = "keyword", text = "ORDER" },
            { type = "keyword", text = "BY" },
            { type = "identifier", text = "created_date" },
            { type = "keyword", text = "DESC" },
            { type = "comma", text = "," },
            { type = "identifier", text = "name" },
            { type = "keyword", text = "ASC" }
        }
    }
}
