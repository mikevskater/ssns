-- Test file: special_chars.lua
-- IDs: 1401-1450
-- Tests: Special character tokenization

return {
    -- Parentheses
    {
        id = 1401,
        type = "tokenizer",
        name = "Left parenthesis",
        input = "(",
        expected = {
            {type = "paren_open", text = "(", line = 1, col = 1}
        }
    },
    {
        id = 1402,
        type = "tokenizer",
        name = "Right parenthesis",
        input = ")",
        expected = {
            {type = "paren_close", text = ")", line = 1, col = 1}
        }
    },
    {
        id = 1403,
        type = "tokenizer",
        name = "Matching parentheses",
        input = "()",
        expected = {
            {type = "paren_open", text = "(", line = 1, col = 1},
            {type = "paren_close", text = ")", line = 1, col = 2}
        }
    },
    {
        id = 1404,
        type = "tokenizer",
        name = "Nested parentheses",
        input = "((()))",
        expected = {
            {type = "paren_open", text = "(", line = 1, col = 1},
            {type = "paren_open", text = "(", line = 1, col = 2},
            {type = "paren_open", text = "(", line = 1, col = 3},
            {type = "paren_close", text = ")", line = 1, col = 4},
            {type = "paren_close", text = ")", line = 1, col = 5},
            {type = "paren_close", text = ")", line = 1, col = 6}
        }
    },

    -- Comma
    {
        id = 1405,
        type = "tokenizer",
        name = "Comma",
        input = ",",
        expected = {
            {type = "comma", text = ",", line = 1, col = 1}
        }
    },
    {
        id = 1406,
        type = "tokenizer",
        name = "Multiple commas",
        input = ",,",
        expected = {
            {type = "comma", text = ",", line = 1, col = 1},
            {type = "comma", text = ",", line = 1, col = 2}
        }
    },
    {
        id = 1407,
        type = "tokenizer",
        name = "Comma-separated list",
        input = "a, b, c",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "comma", text = ",", line = 1, col = 2},
            {type = "identifier", text = "b", line = 1, col = 4},
            {type = "comma", text = ",", line = 1, col = 5},
            {type = "identifier", text = "c", line = 1, col = 7}
        }
    },

    -- Dot
    {
        id = 1408,
        type = "tokenizer",
        name = "Dot",
        input = ".",
        expected = {
            {type = "dot", text = ".", line = 1, col = 1}
        }
    },
    {
        id = 1409,
        type = "tokenizer",
        name = "Qualified identifier",
        input = "schema.table",
        expected = {
            {type = "keyword", text = "schema", line = 1, col = 1},
            {type = "dot", text = ".", line = 1, col = 7},
            {type = "keyword", text = "table", line = 1, col = 8}
        }
    },
    {
        id = 1410,
        type = "tokenizer",
        name = "Three-part identifier",
        input = "database.schema.table",
        expected = {
            {type = "keyword", text = "database", line = 1, col = 1},
            {type = "dot", text = ".", line = 1, col = 9},
            {type = "keyword", text = "schema", line = 1, col = 10},
            {type = "dot", text = ".", line = 1, col = 16},
            {type = "keyword", text = "table", line = 1, col = 17}
        }
    },
    {
        id = 1411,
        type = "tokenizer",
        name = "Four-part identifier",
        input = "server.database.schema.table",
        expected = {
            {type = "identifier", text = "server", line = 1, col = 1},
            {type = "dot", text = ".", line = 1, col = 7},
            {type = "keyword", text = "database", line = 1, col = 8},
            {type = "dot", text = ".", line = 1, col = 16},
            {type = "keyword", text = "schema", line = 1, col = 17},
            {type = "dot", text = ".", line = 1, col = 23},
            {type = "keyword", text = "table", line = 1, col = 24}
        }
    },

    -- Star (asterisk as special, not operator)
    {
        id = 1412,
        type = "tokenizer",
        name = "Star (SELECT *)",
        input = "*",
        expected = {
            {type = "star", text = "*", line = 1, col = 1}
        }
    },
    {
        id = 1413,
        type = "tokenizer",
        name = "Star in SELECT",
        input = "SELECT *",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8}
        }
    },
    {
        id = 1414,
        type = "tokenizer",
        name = "Qualified star",
        input = "table.*",
        expected = {
            {type = "keyword", text = "table", line = 1, col = 1},
            {type = "dot", text = ".", line = 1, col = 6},
            {type = "star", text = "*", line = 1, col = 7}
        }
    },

    -- Semicolon
    {
        id = 1415,
        type = "tokenizer",
        name = "Semicolon",
        input = ";",
        expected = {
            {type = "semicolon", text = ";", line = 1, col = 1}
        }
    },
    {
        id = 1416,
        type = "tokenizer",
        name = "Statement with semicolon",
        input = "SELECT 1;",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "number", text = "1", line = 1, col = 8},
            {type = "semicolon", text = ";", line = 1, col = 9}
        }
    },
    {
        id = 1417,
        type = "tokenizer",
        name = "Multiple statements with semicolons",
        input = "SELECT 1; SELECT 2;",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "number", text = "1", line = 1, col = 8},
            {type = "semicolon", text = ";", line = 1, col = 9},
            {type = "keyword", text = "SELECT", line = 1, col = 11},
            {type = "number", text = "2", line = 1, col = 18},
            {type = "semicolon", text = ";", line = 1, col = 19}
        }
    },

    -- Combinations with keywords
    {
        id = 1418,
        type = "tokenizer",
        name = "SELECT with parentheses",
        input = "SELECT (column)",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "paren_open", text = "(", line = 1, col = 8},
            -- "column" is a SQL keyword
            {type = "keyword", text = "column", line = 1, col = 9},
            {type = "paren_close", text = ")", line = 1, col = 15}
        }
    },
    {
        id = 1419,
        type = "tokenizer",
        name = "Function call",
        input = "COUNT(*)",
        expected = {
            {type = "keyword", text = "COUNT", line = 1, col = 1},
            {type = "paren_open", text = "(", line = 1, col = 6},
            {type = "star", text = "*", line = 1, col = 7},
            {type = "paren_close", text = ")", line = 1, col = 8}
        }
    },
    {
        id = 1420,
        type = "tokenizer",
        name = "Function with arguments",
        input = "MAX(value)",
        expected = {
            {type = "keyword", text = "MAX", line = 1, col = 1},
            {type = "paren_open", text = "(", line = 1, col = 4},
            -- "value" is a SQL keyword
            {type = "keyword", text = "value", line = 1, col = 5},
            {type = "paren_close", text = ")", line = 1, col = 10}
        }
    },

    -- Complex combinations
    {
        id = 1421,
        type = "tokenizer",
        name = "Parentheses with comma",
        input = "(a, b)",
        expected = {
            {type = "paren_open", text = "(", line = 1, col = 1},
            {type = "identifier", text = "a", line = 1, col = 2},
            {type = "comma", text = ",", line = 1, col = 3},
            {type = "identifier", text = "b", line = 1, col = 5},
            {type = "paren_close", text = ")", line = 1, col = 6}
        }
    },
    {
        id = 1422,
        type = "tokenizer",
        name = "Dot and star together",
        input = ".*",
        expected = {
            {type = "dot", text = ".", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 2}
        }
    },
    {
        id = 1423,
        type = "tokenizer",
        name = "All specials in sequence",
        input = "( ) , . * ;",
        expected = {
            {type = "paren_open", text = "(", line = 1, col = 1},
            {type = "paren_close", text = ")", line = 1, col = 3},
            {type = "comma", text = ",", line = 1, col = 5},
            {type = "dot", text = ".", line = 1, col = 7},
            {type = "star", text = "*", line = 1, col = 9},
            {type = "semicolon", text = ";", line = 1, col = 11}
        }
    },

    -- No spaces between specials
    {
        id = 1424,
        type = "tokenizer",
        name = "Parentheses around comma no spaces",
        input = "(a,b)",
        expected = {
            {type = "paren_open", text = "(", line = 1, col = 1},
            {type = "identifier", text = "a", line = 1, col = 2},
            {type = "comma", text = ",", line = 1, col = 3},
            {type = "identifier", text = "b", line = 1, col = 4},
            {type = "paren_close", text = ")", line = 1, col = 5}
        }
    },
    {
        id = 1425,
        type = "tokenizer",
        name = "Qualified identifier no spaces",
        input = "dbo.Table",
        expected = {
            {type = "identifier", text = "dbo", line = 1, col = 1},
            {type = "dot", text = ".", line = 1, col = 4},
            {type = "keyword", text = "Table", line = 1, col = 5}
        }
    },

    -- Real-world SQL patterns
    {
        id = 1426,
        type = "tokenizer",
        name = "Column list in SELECT",
        input = "SELECT a, b, c",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "a", line = 1, col = 8},
            {type = "comma", text = ",", line = 1, col = 9},
            {type = "identifier", text = "b", line = 1, col = 11},
            {type = "comma", text = ",", line = 1, col = 12},
            {type = "identifier", text = "c", line = 1, col = 14}
        }
    },
    {
        id = 1427,
        type = "tokenizer",
        name = "SELECT with qualified columns",
        input = "SELECT t.a, t.b",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "t", line = 1, col = 8},
            {type = "dot", text = ".", line = 1, col = 9},
            {type = "identifier", text = "a", line = 1, col = 10},
            {type = "comma", text = ",", line = 1, col = 11},
            {type = "identifier", text = "t", line = 1, col = 13},
            {type = "dot", text = ".", line = 1, col = 14},
            {type = "identifier", text = "b", line = 1, col = 15}
        }
    },
    {
        id = 1428,
        type = "tokenizer",
        name = "IN clause with values",
        input = "IN (1, 2, 3)",
        expected = {
            {type = "keyword", text = "IN", line = 1, col = 1},
            {type = "paren_open", text = "(", line = 1, col = 4},
            {type = "number", text = "1", line = 1, col = 5},
            {type = "comma", text = ",", line = 1, col = 6},
            {type = "number", text = "2", line = 1, col = 8},
            {type = "comma", text = ",", line = 1, col = 9},
            {type = "number", text = "3", line = 1, col = 11},
            {type = "paren_close", text = ")", line = 1, col = 12}
        }
    },
    {
        id = 1429,
        type = "tokenizer",
        name = "Subquery in parentheses",
        input = "(SELECT *)",
        expected = {
            {type = "paren_open", text = "(", line = 1, col = 1},
            {type = "keyword", text = "SELECT", line = 1, col = 2},
            {type = "star", text = "*", line = 1, col = 9},
            {type = "paren_close", text = ")", line = 1, col = 10}
        }
    },
    {
        id = 1430,
        type = "tokenizer",
        name = "Function with qualified column",
        input = "COUNT(t.id)",
        expected = {
            {type = "keyword", text = "COUNT", line = 1, col = 1},
            {type = "paren_open", text = "(", line = 1, col = 6},
            {type = "identifier", text = "t", line = 1, col = 7},
            {type = "dot", text = ".", line = 1, col = 8},
            {type = "identifier", text = "id", line = 1, col = 9},
            {type = "paren_close", text = ")", line = 1, col = 11}
        }
    },

    -- Edge cases
    {
        id = 1431,
        type = "tokenizer",
        name = "Multiple dots in sequence",
        input = "...",
        expected = {
            {type = "dot", text = ".", line = 1, col = 1},
            {type = "dot", text = ".", line = 1, col = 2},
            {type = "dot", text = ".", line = 1, col = 3}
        }
    },
    {
        id = 1432,
        type = "tokenizer",
        name = "Multiple commas in sequence",
        input = ",,,",
        expected = {
            {type = "comma", text = ",", line = 1, col = 1},
            {type = "comma", text = ",", line = 1, col = 2},
            {type = "comma", text = ",", line = 1, col = 3}
        }
    },
    {
        id = 1433,
        type = "tokenizer",
        name = "Trailing comma",
        input = "a, b,",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "comma", text = ",", line = 1, col = 2},
            {type = "identifier", text = "b", line = 1, col = 4},
            {type = "comma", text = ",", line = 1, col = 5}
        }
    },
    {
        id = 1434,
        type = "tokenizer",
        name = "Leading comma",
        input = ", a",
        expected = {
            {type = "comma", text = ",", line = 1, col = 1},
            {type = "identifier", text = "a", line = 1, col = 3}
        }
    },
    {
        id = 1435,
        type = "tokenizer",
        name = "Unmatched left parenthesis",
        input = "(a",
        expected = {
            {type = "paren_open", text = "(", line = 1, col = 1},
            {type = "identifier", text = "a", line = 1, col = 2}
        }
    },
    {
        id = 1436,
        type = "tokenizer",
        name = "Unmatched right parenthesis",
        input = "a)",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "paren_close", text = ")", line = 1, col = 2}
        }
    },

    -- Multi-line patterns
    {
        id = 1437,
        type = "tokenizer",
        name = "Multi-line comma-separated list",
        input = "a,\nb,\nc",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "comma", text = ",", line = 1, col = 2},
            {type = "identifier", text = "b", line = 2, col = 1},
            {type = "comma", text = ",", line = 2, col = 2},
            {type = "identifier", text = "c", line = 3, col = 1}
        }
    },
    {
        id = 1438,
        type = "tokenizer",
        name = "Multi-line function call",
        input = "COUNT(\n*\n)",
        expected = {
            {type = "keyword", text = "COUNT", line = 1, col = 1},
            {type = "paren_open", text = "(", line = 1, col = 6},
            {type = "star", text = "*", line = 2, col = 1},
            {type = "paren_close", text = ")", line = 3, col = 1}
        }
    },

    -- Brackets (square)
    {
        id = 1439,
        type = "tokenizer",
        name = "Left bracket (unterminated)",
        input = "[",
        expected = {
            {type = "identifier", text = "[", line = 1, col = 1}
        }
    },
    {
        id = 1440,
        type = "tokenizer",
        name = "Right bracket (no opening)",
        input = "]",
        expected = {
            {type = "identifier", text = "]", line = 1, col = 1}
        }
    },
    {
        id = 1441,
        type = "tokenizer",
        name = "Bracketed identifier (full)",
        input = "[Table]",
        expected = {
            {type = "bracket_id", text = "[Table]", line = 1, col = 1}
        }
    },

    -- Additional combinations
    {
        id = 1442,
        type = "tokenizer",
        name = "Complex nested expression",
        input = "((a, b), (c, d))",
        expected = {
            {type = "paren_open", text = "(", line = 1, col = 1},
            {type = "paren_open", text = "(", line = 1, col = 2},
            {type = "identifier", text = "a", line = 1, col = 3},
            {type = "comma", text = ",", line = 1, col = 4},
            {type = "identifier", text = "b", line = 1, col = 6},
            {type = "paren_close", text = ")", line = 1, col = 7},
            {type = "comma", text = ",", line = 1, col = 8},
            {type = "paren_open", text = "(", line = 1, col = 10},
            {type = "identifier", text = "c", line = 1, col = 11},
            {type = "comma", text = ",", line = 1, col = 12},
            {type = "identifier", text = "d", line = 1, col = 14},
            {type = "paren_close", text = ")", line = 1, col = 15},
            {type = "paren_close", text = ")", line = 1, col = 16}
        }
    },
    {
        id = 1443,
        type = "tokenizer",
        name = "Column list with expressions",
        input = "a + b, c * d",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "operator", text = "+", line = 1, col = 3},
            {type = "identifier", text = "b", line = 1, col = 5},
            {type = "comma", text = ",", line = 1, col = 6},
            {type = "identifier", text = "c", line = 1, col = 8},
            {type = "star", text = "*", line = 1, col = 10},
            {type = "identifier", text = "d", line = 1, col = 12}
        }
    },
    {
        id = 1444,
        type = "tokenizer",
        name = "Empty parentheses",
        input = "()",
        expected = {
            {type = "paren_open", text = "(", line = 1, col = 1},
            {type = "paren_close", text = ")", line = 1, col = 2}
        }
    },
    {
        id = 1445,
        type = "tokenizer",
        name = "Dot at start",
        input = ".column",
        expected = {
            {type = "dot", text = ".", line = 1, col = 1},
            -- "column" is a SQL keyword
            {type = "keyword", text = "column", line = 1, col = 2}
        }
    },
    {
        id = 1446,
        type = "tokenizer",
        name = "Dot at end",
        input = "table.",
        expected = {
            {type = "keyword", text = "table", line = 1, col = 1},
            {type = "dot", text = ".", line = 1, col = 6}
        }
    },
    {
        id = 1447,
        type = "tokenizer",
        name = "Star between operators",
        input = "a * b",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 3},
            {type = "identifier", text = "b", line = 1, col = 5}
        }
    },
    {
        id = 1448,
        type = "tokenizer",
        name = "Mixed specials and operators",
        input = "(a + b) * c",
        expected = {
            {type = "paren_open", text = "(", line = 1, col = 1},
            {type = "identifier", text = "a", line = 1, col = 2},
            {type = "operator", text = "+", line = 1, col = 4},
            {type = "identifier", text = "b", line = 1, col = 6},
            {type = "paren_close", text = ")", line = 1, col = 7},
            {type = "star", text = "*", line = 1, col = 9},
            {type = "identifier", text = "c", line = 1, col = 11}
        }
    },
    {
        id = 1449,
        type = "tokenizer",
        name = "Statement terminator variations",
        input = ";;",
        expected = {
            {type = "semicolon", text = ";", line = 1, col = 1},
            {type = "semicolon", text = ";", line = 1, col = 2}
        }
    },
    {
        id = 1450,
        type = "tokenizer",
        name = "All specials without spaces",
        input = "(),.;*",
        expected = {
            {type = "paren_open", text = "(", line = 1, col = 1},
            {type = "paren_close", text = ")", line = 1, col = 2},
            {type = "comma", text = ",", line = 1, col = 3},
            {type = "dot", text = ".", line = 1, col = 4},
            {type = "semicolon", text = ";", line = 1, col = 5},
            {type = "star", text = "*", line = 1, col = 6}
        }
    },
}
