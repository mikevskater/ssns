-- Test file: edge_cases.lua
-- IDs: 1601-1650
-- Tests: Edge cases and error handling

return {
    -- Empty and whitespace
    {
        id = 1601,
        type = "tokenizer",
        name = "Empty input",
        input = "",
        expected = {}
    },
    {
        id = 1602,
        type = "tokenizer",
        name = "Only spaces",
        input = "   ",
        expected = {}
    },
    {
        id = 1603,
        type = "tokenizer",
        name = "Only tabs",
        input = "\t\t\t",
        expected = {}
    },
    {
        id = 1604,
        type = "tokenizer",
        name = "Only newlines",
        input = "\n\n\n",
        expected = {}
    },
    {
        id = 1605,
        type = "tokenizer",
        name = "Mixed whitespace",
        input = "  \t\n  \t\n  ",
        expected = {}
    },
    {
        id = 1606,
        type = "tokenizer",
        name = "Whitespace before and after token",
        input = "   SELECT   ",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 4}
        }
    },

    -- Only comments (comments are now emitted as tokens)
    {
        id = 1607,
        type = "tokenizer",
        name = "Only line comment",
        input = "-- this is a comment",
        expected = {
            {type = "line_comment", text = "-- this is a comment", line = 1, col = 1}
        }
    },
    {
        id = 1608,
        type = "tokenizer",
        name = "Only block comment",
        input = "/* this is a comment */",
        expected = {
            {type = "comment", text = "/* this is a comment */", line = 1, col = 1}
        }
    },
    {
        id = 1609,
        type = "tokenizer",
        name = "Multiple line comments only",
        input = "-- comment 1\n-- comment 2\n-- comment 3",
        expected = {
            {type = "line_comment", text = "-- comment 1", line = 1, col = 1},
            {type = "line_comment", text = "-- comment 2", line = 2, col = 1},
            {type = "line_comment", text = "-- comment 3", line = 3, col = 1}
        }
    },
    {
        id = 1610,
        type = "tokenizer",
        name = "Multiple block comments only",
        input = "/* comment 1 */ /* comment 2 */ /* comment 3 */",
        expected = {
            {type = "comment", text = "/* comment 1 */", line = 1, col = 1},
            {type = "comment", text = "/* comment 2 */", line = 1, col = 17},
            {type = "comment", text = "/* comment 3 */", line = 1, col = 33}
        }
    },

    -- Unterminated strings (should handle gracefully)
    {
        id = 1611,
        type = "tokenizer",
        name = "Unterminated string at end",
        input = "SELECT 'unterminated",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "'unterminated", line = 1, col = 8}
        }
    },
    {
        id = 1612,
        type = "tokenizer",
        name = "Unterminated string with escaped quote",
        input = "SELECT 'it''s unterminated'",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "string", text = "'it''s unterminated'", line = 1, col = 8}
        }
    },
    {
        id = 1613,
        type = "tokenizer",
        name = "String starting but no content",
        input = "SELECT '",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "'", line = 1, col = 8}
        }
    },

    -- Unterminated bracket identifier (should handle gracefully)
    {
        id = 1614,
        type = "tokenizer",
        name = "Unterminated bracket identifier",
        input = "SELECT [TableName",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "[TableName", line = 1, col = 8}
        }
    },
    {
        id = 1615,
        type = "tokenizer",
        name = "Bracket identifier with no content",
        input = "SELECT [",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "[", line = 1, col = 8}
        }
    },

    -- Unterminated block comment (should handle gracefully - comment token still emitted)
    {
        id = 1616,
        type = "tokenizer",
        name = "Unterminated block comment",
        input = "SELECT /* comment without end",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "comment", text = "/* comment without end", line = 1, col = 8}
        }
    },
    {
        id = 1617,
        type = "tokenizer",
        name = "Block comment start only",
        input = "SELECT /*",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "comment", text = "/*", line = 1, col = 8}
        }
    },

    -- Very long identifiers
    {
        id = 1618,
        type = "tokenizer",
        name = "Very long identifier",
        input = "ThisIsAVeryLongIdentifierNameThatGoesOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOn",
        expected = {
            {type = "identifier", text = "ThisIsAVeryLongIdentifierNameThatGoesOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOnAndOn", line = 1, col = 1}
        }
    },
    {
        id = 1619,
        type = "tokenizer",
        name = "Very long bracketed identifier",
        input = "[This Is A Very Long Identifier Name With Spaces That Goes On And On And On And On And On And On]",
        expected = {
            {type = "bracket_id", text = "[This Is A Very Long Identifier Name With Spaces That Goes On And On And On And On And On And On]", line = 1, col = 1}
        }
    },

    -- Very long strings
    {
        id = 1620,
        type = "tokenizer",
        name = "Very long string",
        input = "'This is a very long string that contains many many many many many many many many many many many many words'",
        expected = {
            {type = "string", text = "'This is a very long string that contains many many many many many many many many many many many many words'", line = 1, col = 1}
        }
    },

    -- Unicode in strings (if supported)
    {
        id = 1621,
        type = "tokenizer",
        name = "String with unicode characters",
        input = "'Hello 世界 🌍'",
        expected = {
            {type = "string", text = "'Hello 世界 🌍'", line = 1, col = 1}
        }
    },
    {
        id = 1622,
        type = "tokenizer",
        name = "String with emoji",
        input = "'😀😃😄😁'",
        expected = {
            {type = "string", text = "'😀😃😄😁'", line = 1, col = 1}
        }
    },
    {
        id = 1623,
        type = "tokenizer",
        name = "String with accented characters",
        input = "'café résumé naïve'",
        expected = {
            {type = "string", text = "'café résumé naïve'", line = 1, col = 1}
        }
    },

    -- Mixed case keywords
    {
        id = 1624,
        type = "tokenizer",
        name = "Mixed case SELECT",
        input = "SeLeCt",
        expected = {
            {type = "keyword", text = "SeLeCt", line = 1, col = 1}
        }
    },
    {
        id = 1625,
        type = "tokenizer",
        name = "Lowercase keywords",
        input = "select from where",
        expected = {
            {type = "keyword", text = "select", line = 1, col = 1},
            {type = "keyword", text = "from", line = 1, col = 8},
            {type = "keyword", text = "where", line = 1, col = 13}
        }
    },
    {
        id = 1626,
        type = "tokenizer",
        name = "Mixed case statement",
        input = "SeLeCt * FrOm TaBlE wHeRe Id = 1",
        expected = {
            {type = "keyword", text = "SeLeCt", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FrOm", line = 1, col = 10},
            {type = "keyword", text = "TaBlE", line = 1, col = 15},
            {type = "keyword", text = "wHeRe", line = 1, col = 21},
            {type = "identifier", text = "Id", line = 1, col = 27},
            {type = "operator", text = "=", line = 1, col = 30},
            {type = "number", text = "1", line = 1, col = 32}
        }
    },

    -- Special character sequences
    {
        id = 1627,
        type = "tokenizer",
        name = "Multiple dots in a row",
        input = "a...b",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "dot", text = ".", line = 1, col = 2},
            {type = "dot", text = ".", line = 1, col = 3},
            {type = "dot", text = ".", line = 1, col = 4},
            {type = "identifier", text = "b", line = 1, col = 5}
        }
    },
    {
        id = 1628,
        type = "tokenizer",
        name = "Multiple commas in a row",
        input = "a,,,b",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "comma", text = ",", line = 1, col = 2},
            {type = "comma", text = ",", line = 1, col = 3},
            {type = "comma", text = ",", line = 1, col = 4},
            {type = "identifier", text = "b", line = 1, col = 5}
        }
    },

    -- Numbers that could be ambiguous
    {
        id = 1629,
        type = "tokenizer",
        name = "Number followed immediately by letter",
        input = "123abc",
        expected = {
            {type = "identifier", text = "123abc", line = 1, col = 1}
        }
    },
    {
        id = 1630,
        type = "tokenizer",
        name = "Decimal followed by identifier",
        input = "3.14abc",
        expected = {
            -- When number followed by dot followed by alphanumerics,
            -- the tokenizer treats the whole thing as a single identifier
            {type = "identifier", text = "3.14abc", line = 1, col = 1}
        }
    },

    -- Operators in unusual contexts
    {
        id = 1631,
        type = "tokenizer",
        name = "Many operators in sequence",
        input = "+-*/%=<>",
        expected = {
            {type = "operator", text = "+", line = 1, col = 1},
            {type = "operator", text = "-", line = 1, col = 2},
            {type = "star", text = "*", line = 1, col = 3},
            {type = "operator", text = "/", line = 1, col = 4},
            {type = "operator", text = "%", line = 1, col = 5},
            {type = "operator", text = "=", line = 1, col = 6},
            -- <> is now a single multi-character operator
            {type = "operator", text = "<>", line = 1, col = 7}
        }
    },

    -- Strings with special content
    {
        id = 1632,
        type = "tokenizer",
        name = "String with newline character (escaped)",
        input = "'line1\\nline2'",
        expected = {
            {type = "string", text = "'line1\\nline2'", line = 1, col = 1}
        }
    },
    {
        id = 1633,
        type = "tokenizer",
        name = "String with tab character (escaped)",
        input = "'col1\\tcol2'",
        expected = {
            {type = "string", text = "'col1\\tcol2'", line = 1, col = 1}
        }
    },
    {
        id = 1634,
        type = "tokenizer",
        name = "String with backslash",
        input = "'C:\\\\path\\\\to\\\\file'",
        expected = {
            {type = "string", text = "'C:\\\\path\\\\to\\\\file'", line = 1, col = 1}
        }
    },

    -- Multiple statements
    {
        id = 1635,
        type = "tokenizer",
        name = "Multiple statements with semicolons",
        input = "SELECT 1; SELECT 2; SELECT 3;",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "number", text = "1", line = 1, col = 8},
            {type = "semicolon", text = ";", line = 1, col = 9},
            {type = "keyword", text = "SELECT", line = 1, col = 11},
            {type = "number", text = "2", line = 1, col = 18},
            {type = "semicolon", text = ";", line = 1, col = 19},
            {type = "keyword", text = "SELECT", line = 1, col = 21},
            {type = "number", text = "3", line = 1, col = 28},
            {type = "semicolon", text = ";", line = 1, col = 29}
        }
    },

    -- GO batch separator (SQL Server specific) - now recognized as go token type
    {
        id = 1636,
        type = "tokenizer",
        name = "GO batch separator",
        input = "SELECT 1\nGO\nSELECT 2",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "number", text = "1", line = 1, col = 8},
            {type = "go", text = "GO", line = 2, col = 1},
            {type = "keyword", text = "SELECT", line = 3, col = 1},
            {type = "number", text = "2", line = 3, col = 8}
        }
    },
    {
        id = 1637,
        type = "tokenizer",
        name = "GO in mixed case",
        input = "SELECT 1\nGo\nSELECT 2",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "number", text = "1", line = 1, col = 8},
            {type = "go", text = "Go", line = 2, col = 1},
            {type = "keyword", text = "SELECT", line = 3, col = 1},
            {type = "number", text = "2", line = 3, col = 8}
        }
    },

    -- Single character tokens
    {
        id = 1638,
        type = "tokenizer",
        name = "All single characters",
        input = "a 1 * + - / = < > ( ) , . ;",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "number", text = "1", line = 1, col = 3},
            {type = "star", text = "*", line = 1, col = 5},
            {type = "operator", text = "+", line = 1, col = 7},
            {type = "operator", text = "-", line = 1, col = 9},
            {type = "operator", text = "/", line = 1, col = 11},
            {type = "operator", text = "=", line = 1, col = 13},
            {type = "operator", text = "<", line = 1, col = 15},
            {type = "operator", text = ">", line = 1, col = 17},
            {type = "paren_open", text = "(", line = 1, col = 19},
            {type = "paren_close", text = ")", line = 1, col = 21},
            {type = "comma", text = ",", line = 1, col = 23},
            {type = "dot", text = ".", line = 1, col = 25},
            {type = "semicolon", text = ";", line = 1, col = 27}
        }
    },

    -- Pathological cases
    {
        id = 1639,
        type = "tokenizer",
        name = "Empty parentheses repeated",
        input = "()()()",
        expected = {
            {type = "paren_open", text = "(", line = 1, col = 1},
            {type = "paren_close", text = ")", line = 1, col = 2},
            {type = "paren_open", text = "(", line = 1, col = 3},
            {type = "paren_close", text = ")", line = 1, col = 4},
            {type = "paren_open", text = "(", line = 1, col = 5},
            {type = "paren_close", text = ")", line = 1, col = 6}
        }
    },
    {
        id = 1640,
        type = "tokenizer",
        name = "Deeply nested parentheses",
        input = "((((((a))))))",
        expected = {
            {type = "paren_open", text = "(", line = 1, col = 1},
            {type = "paren_open", text = "(", line = 1, col = 2},
            {type = "paren_open", text = "(", line = 1, col = 3},
            {type = "paren_open", text = "(", line = 1, col = 4},
            {type = "paren_open", text = "(", line = 1, col = 5},
            {type = "paren_open", text = "(", line = 1, col = 6},
            {type = "identifier", text = "a", line = 1, col = 7},
            {type = "paren_close", text = ")", line = 1, col = 8},
            {type = "paren_close", text = ")", line = 1, col = 9},
            {type = "paren_close", text = ")", line = 1, col = 10},
            {type = "paren_close", text = ")", line = 1, col = 11},
            {type = "paren_close", text = ")", line = 1, col = 12},
            {type = "paren_close", text = ")", line = 1, col = 13}
        }
    },

    -- Repeated special sequences
    {
        id = 1641,
        type = "tokenizer",
        name = "Many semicolons",
        input = ";;;;",
        expected = {
            {type = "semicolon", text = ";", line = 1, col = 1},
            {type = "semicolon", text = ";", line = 1, col = 2},
            {type = "semicolon", text = ";", line = 1, col = 3},
            {type = "semicolon", text = ";", line = 1, col = 4}
        }
    },

    -- Special identifier cases
    {
        id = 1642,
        type = "tokenizer",
        name = "Identifier that looks like number",
        input = "_123",
        expected = {
            {type = "identifier", text = "_123", line = 1, col = 1}
        }
    },
    {
        id = 1643,
        type = "tokenizer",
        name = "All underscores",
        input = "____",
        expected = {
            {type = "identifier", text = "____", line = 1, col = 1}
        }
    },

    -- Comment edge cases (comments now emitted as tokens)
    {
        id = 1644,
        type = "tokenizer",
        name = "Comment with SQL injection attempt",
        input = "SELECT * FROM Users -- '; DROP TABLE Users; --",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "Users", line = 1, col = 15},
            {type = "line_comment", text = "-- '; DROP TABLE Users; --", line = 1, col = 21}
        }
    },
    {
        id = 1645,
        type = "tokenizer",
        name = "Block comment with asterisks inside",
        input = "/* *** comment *** */",
        expected = {
            {type = "comment", text = "/* *** comment *** */", line = 1, col = 1}
        }
    },
    {
        id = 1646,
        type = "tokenizer",
        name = "Block comment with forward slashes inside",
        input = "/* /// comment /// */",
        expected = {
            {type = "comment", text = "/* /// comment /// */", line = 1, col = 1}
        }
    },

    -- Whitespace variations
    {
        id = 1647,
        type = "tokenizer",
        name = "Tab-separated tokens",
        input = "SELECT\t*\tFROM\tUsers",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "Users", line = 1, col = 15}
        }
    },
    {
        id = 1648,
        type = "tokenizer",
        name = "Mixed tabs and spaces",
        input = "SELECT \t * \t FROM  \tUsers",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 10},
            {type = "keyword", text = "FROM", line = 1, col = 14},
            {type = "identifier", text = "Users", line = 1, col = 21}
        }
    },

    -- Realistic edge case
    {
        id = 1649,
        type = "tokenizer",
        name = "Complex statement with all token types",
        input = "SELECT t1.*, COUNT(*) AS cnt FROM [My Schema].[My Table] t1 WHERE t1.id IN (1, 2, 3) AND t1.name LIKE 'test%' -- comment",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "t1", line = 1, col = 8},
            {type = "dot", text = ".", line = 1, col = 10},
            {type = "star", text = "*", line = 1, col = 11},
            {type = "comma", text = ",", line = 1, col = 12},
            {type = "keyword", text = "COUNT", line = 1, col = 14},  -- COUNT is now keyword
            {type = "paren_open", text = "(", line = 1, col = 19},
            {type = "star", text = "*", line = 1, col = 20},
            {type = "paren_close", text = ")", line = 1, col = 21},
            {type = "keyword", text = "AS", line = 1, col = 23},
            {type = "identifier", text = "cnt", line = 1, col = 26},
            {type = "keyword", text = "FROM", line = 1, col = 30},
            {type = "bracket_id", text = "[My Schema]", line = 1, col = 35},
            {type = "dot", text = ".", line = 1, col = 46},
            {type = "bracket_id", text = "[My Table]", line = 1, col = 47},
            {type = "identifier", text = "t1", line = 1, col = 58},
            {type = "keyword", text = "WHERE", line = 1, col = 61},
            {type = "identifier", text = "t1", line = 1, col = 67},
            {type = "dot", text = ".", line = 1, col = 69},
            {type = "identifier", text = "id", line = 1, col = 70},
            {type = "keyword", text = "IN", line = 1, col = 73},
            {type = "paren_open", text = "(", line = 1, col = 76},
            {type = "number", text = "1", line = 1, col = 77},
            {type = "comma", text = ",", line = 1, col = 78},
            {type = "number", text = "2", line = 1, col = 80},
            {type = "comma", text = ",", line = 1, col = 81},
            {type = "number", text = "3", line = 1, col = 83},
            {type = "paren_close", text = ")", line = 1, col = 84},
            {type = "keyword", text = "AND", line = 1, col = 86},
            {type = "identifier", text = "t1", line = 1, col = 90},
            {type = "dot", text = ".", line = 1, col = 92},
            {type = "identifier", text = "name", line = 1, col = 93},
            {type = "keyword", text = "LIKE", line = 1, col = 98},
            {type = "string", text = "'test%'", line = 1, col = 103},
            {type = "line_comment", text = "-- comment", line = 1, col = 111}  -- comment now emitted
        }
    },

    -- Final comprehensive test
    {
        id = 1650,
        type = "tokenizer",
        name = "Kitchen sink - all features",
        input = "/* Multi-line\ncomment */\nSELECT #temp.*, 'O''Brien', 3.14, @var FROM [dbo].[Table] -- inline comment\nWHERE id >= 1 AND name <> 'test';",
        expected = {
            {type = "comment", text = "/* Multi-line\ncomment */", line = 1, col = 1},  -- multi-line comment emitted
            {type = "keyword", text = "SELECT", line = 3, col = 1},
            {type = "temp_table", text = "#temp", line = 3, col = 8},  -- #temp as single temp_table token
            {type = "dot", text = ".", line = 3, col = 13},
            {type = "star", text = "*", line = 3, col = 14},
            {type = "comma", text = ",", line = 3, col = 15},
            {type = "string", text = "'O''Brien'", line = 3, col = 17},
            {type = "comma", text = ",", line = 3, col = 27},
            {type = "number", text = "3.14", line = 3, col = 29},  -- decimal as single number token
            {type = "comma", text = ",", line = 3, col = 33},
            {type = "variable", text = "@var", line = 3, col = 35},  -- @var as single variable token
            {type = "keyword", text = "FROM", line = 3, col = 40},
            {type = "bracket_id", text = "[dbo]", line = 3, col = 45},
            {type = "dot", text = ".", line = 3, col = 50},
            {type = "bracket_id", text = "[Table]", line = 3, col = 51},
            {type = "line_comment", text = "-- inline comment", line = 3, col = 59},  -- inline comment emitted
            {type = "keyword", text = "WHERE", line = 4, col = 1},
            {type = "identifier", text = "id", line = 4, col = 7},
            {type = "operator", text = ">=", line = 4, col = 10},  -- >= as single operator
            {type = "number", text = "1", line = 4, col = 13},
            {type = "keyword", text = "AND", line = 4, col = 15},
            {type = "identifier", text = "name", line = 4, col = 19},
            {type = "operator", text = "<>", line = 4, col = 24},  -- <> as single operator
            {type = "string", text = "'test'", line = 4, col = 27},
            {type = "semicolon", text = ";", line = 4, col = 33}
        }
    },
}
