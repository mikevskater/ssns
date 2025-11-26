-- Test file: production_queries.lua
-- IDs: 1501-1550
-- Tests: Production-style tokenization edge cases

return {
    -- IDs 1501-1510: Complex String Patterns
    {
        id = 1501,
        type = "tokenizer",
        name = "String with escaped single quotes",
        input = "SELECT 'It''s a test'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "'It''s a test'" }
        }
    },
    {
        id = 1502,
        type = "tokenizer",
        name = "Unicode string with N prefix",
        input = "SELECT N'Hello World'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "identifier", text = "N" },
            { type = "string", text = "'Hello World'" }
        }
    },
    {
        id = 1503,
        type = "tokenizer",
        name = "Multi-line string literal",
        input = "SELECT 'Line 1\nLine 2\nLine 3'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "'Line 1\nLine 2\nLine 3'" }
        }
    },
    {
        id = 1504,
        type = "tokenizer",
        name = "Empty string literal",
        input = "SELECT ''",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "''" }
        }
    },
    {
        id = 1505,
        type = "tokenizer",
        name = "String containing SQL keywords",
        input = "SELECT 'SELECT * FROM Users WHERE id = 1'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "'SELECT * FROM Users WHERE id = 1'" }
        }
    },
    {
        id = 1506,
        type = "tokenizer",
        name = "String with numbers and operators",
        input = "SELECT '123 + 456 = 579'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "'123 + 456 = 579'" }
        }
    },
    {
        id = 1507,
        type = "tokenizer",
        name = "String with special characters",
        input = "SELECT 'Email: user@example.com, Phone: (555) 123-4567'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "'Email: user@example.com, Phone: (555) 123-4567'" }
        }
    },
    {
        id = 1508,
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
        id = 1509,
        type = "tokenizer",
        name = "Unicode string with escaped quotes",
        input = "SELECT N'It''s unicode'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "identifier", text = "N" },
            { type = "string", text = "'It''s unicode'" }
        }
    },
    {
        id = 1510,
        type = "tokenizer",
        name = "String with backslashes",
        input = "SELECT 'C:\\Windows\\System32\\config'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "string", text = "'C:\\Windows\\System32\\config'" }
        }
    },

    -- IDs 1511-1520: Comment Patterns
    {
        id = 1511,
        type = "tokenizer",
        name = "Single line comment at end",
        input = "SELECT * FROM Users -- Get all users",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" }
        }
    },
    {
        id = 1512,
        type = "tokenizer",
        name = "Block comment between keywords",
        input = "SELECT /* comment */ * FROM Users",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" }
        }
    },
    {
        id = 1513,
        type = "tokenizer",
        name = "Multi-line block comment",
        input = "SELECT /*\n  Multi-line\n  comment\n*/ * FROM Users",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" }
        }
    },
    {
        id = 1514,
        type = "tokenizer",
        name = "Comment containing string",
        input = "SELECT * FROM Users -- WHERE name = 'John'",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" }
        }
    },
    {
        id = 1515,
        type = "tokenizer",
        name = "Comment containing code",
        input = "SELECT id, name /* , email, phone */ FROM Users",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "identifier", text = "id" },
            { type = "comma", text = "," },
            { type = "identifier", text = "name" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" }
        }
    },
    {
        id = 1516,
        type = "tokenizer",
        name = "Multiple single-line comments",
        input = "SELECT * -- comment 1\nFROM Users -- comment 2",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" }
        }
    },
    {
        id = 1517,
        type = "tokenizer",
        name = "Block comment at start",
        input = "/* Header comment */ SELECT * FROM Users",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" }
        }
    },
    {
        id = 1518,
        type = "tokenizer",
        name = "Comment with special characters",
        input = "SELECT * FROM Users -- TODO: Fix this @bug #123",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" }
        }
    },
    {
        id = 1519,
        type = "tokenizer",
        name = "Multiple block comments",
        input = "SELECT /* c1 */ * /* c2 */ FROM /* c3 */ Users",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" }
        }
    },
    {
        id = 1520,
        type = "tokenizer",
        name = "Mixed comment styles",
        input = "/* Block */ SELECT * FROM Users -- Line",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "star", text = "*" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Users" }
        }
    },

    -- IDs 1521-1530: Bracketed Identifier Patterns
    {
        id = 1521,
        type = "tokenizer",
        name = "Simple bracketed identifier",
        input = "SELECT [TableName]",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "bracket_id", text = "[TableName]" }
        }
    },
    {
        id = 1522,
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
        id = 1523,
        type = "tokenizer",
        name = "Bracketed identifier with special characters",
        input = "SELECT [Table.Name@2024]",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "bracket_id", text = "[Table.Name@2024]" }
        }
    },
    {
        id = 1524,
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
        id = 1525,
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
        id = 1526,
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
        id = 1527,
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
        id = 1528,
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
        id = 1529,
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
        id = 1530,
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

    -- IDs 1531-1540: Operator and Special Character Patterns
    {
        id = 1531,
        type = "tokenizer",
        name = "Multiple comparison operators",
        input = "WHERE a <= 5 AND b >= 10 AND c <> 0",
        expected = {
            { type = "keyword", text = "WHERE" },
            { type = "identifier", text = "a" },
            { type = "operator", text = "<" },
            { type = "operator", text = "=" },
            { type = "number", text = "5" },
            { type = "keyword", text = "AND" },
            { type = "identifier", text = "b" },
            { type = "operator", text = ">" },
            { type = "operator", text = "=" },
            { type = "number", text = "10" },
            { type = "keyword", text = "AND" },
            { type = "identifier", text = "c" },
            { type = "operator", text = "<" },
            { type = "operator", text = ">" },
            { type = "number", text = "0" }
        }
    },
    {
        id = 1532,
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
        id = 1533,
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
        id = 1534,
        type = "tokenizer",
        name = "Assignment operators",
        input = "SET @counter += 1",
        expected = {
            { type = "keyword", text = "SET" },
            { type = "at", text = "@" },
            { type = "identifier", text = "counter" },
            { type = "operator", text = "+" },
            { type = "operator", text = "=" },
            { type = "number", text = "1" }
        }
    },
    {
        id = 1535,
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
        id = 1536,
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
        id = 1537,
        type = "tokenizer",
        name = "Not equal operators both styles",
        input = "WHERE a <> 0 AND b != 0",
        expected = {
            { type = "keyword", text = "WHERE" },
            { type = "identifier", text = "a" },
            { type = "operator", text = "<" },
            { type = "operator", text = ">" },
            { type = "number", text = "0" },
            { type = "keyword", text = "AND" },
            { type = "identifier", text = "b" },
            { type = "operator", text = "!" },
            { type = "operator", text = "=" },
            { type = "number", text = "0" }
        }
    },
    {
        id = 1538,
        type = "tokenizer",
        name = "Compound assignment operators",
        input = "SET @a += 1, @b -= 2, @c *= 3, @d /= 4",
        expected = {
            { type = "keyword", text = "SET" },
            { type = "at", text = "@" },
            { type = "identifier", text = "a" },
            { type = "operator", text = "+" },
            { type = "operator", text = "=" },
            { type = "number", text = "1" },
            { type = "comma", text = "," },
            { type = "at", text = "@" },
            { type = "identifier", text = "b" },
            { type = "operator", text = "-" },
            { type = "operator", text = "=" },
            { type = "number", text = "2" },
            { type = "comma", text = "," },
            { type = "at", text = "@" },
            { type = "identifier", text = "c" },
            { type = "star", text = "*" },
            { type = "operator", text = "=" },
            { type = "number", text = "3" },
            { type = "comma", text = "," },
            { type = "at", text = "@" },
            { type = "identifier", text = "d" },
            { type = "operator", text = "/" },
            { type = "operator", text = "=" },
            { type = "number", text = "4" }
        }
    },
    {
        id = 1539,
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
        id = 1540,
        type = "tokenizer",
        name = "Negative number",
        input = "SELECT -100",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "operator", text = "-" },
            { type = "number", text = "100" }
        }
    },

    -- IDs 1541-1550: Production Query Tokenization
    {
        id = 1541,
        type = "tokenizer",
        name = "Variable and temp table references",
        input = "SELECT @UserId FROM #TempUsers",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "at", text = "@" },
            { type = "identifier", text = "UserId" },
            { type = "keyword", text = "FROM" },
            { type = "hash", text = "#" },
            { type = "identifier", text = "TempUsers" }
        }
    },
    {
        id = 1542,
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
        id = 1543,
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
        id = 1544,
        type = "tokenizer",
        name = "WHERE with multiple conditions",
        input = "WHERE age >= 18 AND status = 'active' AND city = 'New York'",
        expected = {
            { type = "keyword", text = "WHERE" },
            { type = "identifier", text = "age" },
            { type = "operator", text = ">" },
            { type = "operator", text = "=" },
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
        id = 1545,
        type = "tokenizer",
        name = "GROUP BY with HAVING",
        input = "SELECT category, COUNT(*) FROM Products GROUP BY category HAVING COUNT(*) > 5",
        expected = {
            { type = "keyword", text = "SELECT" },
            { type = "identifier", text = "category" },
            { type = "comma", text = "," },
            { type = "identifier", text = "COUNT" },
            { type = "paren_open", text = "(" },
            { type = "star", text = "*" },
            { type = "paren_close", text = ")" },
            { type = "keyword", text = "FROM" },
            { type = "identifier", text = "Products" },
            { type = "keyword", text = "GROUP" },
            { type = "keyword", text = "BY" },
            { type = "identifier", text = "category" },
            { type = "keyword", text = "HAVING" },
            { type = "identifier", text = "COUNT" },
            { type = "paren_open", text = "(" },
            { type = "star", text = "*" },
            { type = "paren_close", text = ")" },
            { type = "operator", text = ">" },
            { type = "number", text = "5" }
        }
    },
    {
        id = 1546,
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
        id = 1547,
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
        id = 1548,
        type = "tokenizer",
        name = "EXEC stored procedure with parameters",
        input = "EXEC GetUserById @UserId = 123",
        expected = {
            { type = "keyword", text = "EXEC" },
            { type = "identifier", text = "GetUserById" },
            { type = "at", text = "@" },
            { type = "identifier", text = "UserId" },
            { type = "operator", text = "=" },
            { type = "number", text = "123" }
        }
    },
    {
        id = 1549,
        type = "tokenizer",
        name = "DECLARE variables",
        input = "DECLARE @StartDate DATE, @EndDate DATE",
        expected = {
            { type = "keyword", text = "DECLARE" },
            { type = "at", text = "@" },
            { type = "identifier", text = "StartDate" },
            { type = "identifier", text = "DATE" },
            { type = "comma", text = "," },
            { type = "at", text = "@" },
            { type = "identifier", text = "EndDate" },
            { type = "identifier", text = "DATE" }
        }
    },
    {
        id = 1550,
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
