-- Test file: strings_comments.lua
-- IDs: 1201-1250
-- Tests: String literals and comment handling

return {
    -- Simple strings
    {
        id = 1201,
        type = "tokenizer",
        name = "Simple string - hello",
        input = "'hello'",
        expected = {
            {type = "string", text = "'hello'", line = 1, col = 1}
        }
    },
    {
        id = 1202,
        type = "tokenizer",
        name = "Simple string - world",
        input = "'world'",
        expected = {
            {type = "string", text = "'world'", line = 1, col = 1}
        }
    },
    {
        id = 1203,
        type = "tokenizer",
        name = "Empty string",
        input = "''",
        expected = {
            {type = "string", text = "''", line = 1, col = 1}
        }
    },
    {
        id = 1204,
        type = "tokenizer",
        name = "String with single character",
        input = "'a'",
        expected = {
            {type = "string", text = "'a'", line = 1, col = 1}
        }
    },
    {
        id = 1205,
        type = "tokenizer",
        name = "String with numbers",
        input = "'123'",
        expected = {
            {type = "string", text = "'123'", line = 1, col = 1}
        }
    },

    -- Escaped quotes
    {
        id = 1206,
        type = "tokenizer",
        name = "Escaped quote - it's",
        input = "'it''s'",
        expected = {
            {type = "string", text = "'it''s'", line = 1, col = 1}
        }
    },
    {
        id = 1207,
        type = "tokenizer",
        name = "Escaped quote - O'Brien",
        input = "'O''Brien'",
        expected = {
            {type = "string", text = "'O''Brien'", line = 1, col = 1}
        }
    },
    {
        id = 1208,
        type = "tokenizer",
        name = "Multiple escaped quotes",
        input = "'it''s O''Brien''s'",
        expected = {
            {type = "string", text = "'it''s O''Brien''s'", line = 1, col = 1}
        }
    },
    {
        id = 1209,
        type = "tokenizer",
        name = "String with only escaped quote",
        input = "''''",
        expected = {
            {type = "string", text = "''''", line = 1, col = 1}
        }
    },
    {
        id = 1210,
        type = "tokenizer",
        name = "String with double escaped quotes",
        input = "''''''",
        expected = {
            {type = "string", text = "''''''", line = 1, col = 1}
        }
    },

    -- Strings with spaces
    {
        id = 1211,
        type = "tokenizer",
        name = "String with spaces - hello world",
        input = "'hello world'",
        expected = {
            {type = "string", text = "'hello world'", line = 1, col = 1}
        }
    },
    {
        id = 1212,
        type = "tokenizer",
        name = "String with leading space",
        input = "' hello'",
        expected = {
            {type = "string", text = "' hello'", line = 1, col = 1}
        }
    },
    {
        id = 1213,
        type = "tokenizer",
        name = "String with trailing space",
        input = "'hello '",
        expected = {
            {type = "string", text = "'hello '", line = 1, col = 1}
        }
    },
    {
        id = 1214,
        type = "tokenizer",
        name = "String with multiple spaces",
        input = "'hello   world'",
        expected = {
            {type = "string", text = "'hello   world'", line = 1, col = 1}
        }
    },
    {
        id = 1215,
        type = "tokenizer",
        name = "String with only spaces",
        input = "'   '",
        expected = {
            {type = "string", text = "'   '", line = 1, col = 1}
        }
    },

    -- Strings with special characters
    {
        id = 1216,
        type = "tokenizer",
        name = "String with comma",
        input = "'a,b,c'",
        expected = {
            {type = "string", text = "'a,b,c'", line = 1, col = 1}
        }
    },
    {
        id = 1217,
        type = "tokenizer",
        name = "String with dots",
        input = "'a.b.c'",
        expected = {
            {type = "string", text = "'a.b.c'", line = 1, col = 1}
        }
    },
    {
        id = 1218,
        type = "tokenizer",
        name = "String with brackets",
        input = "'[test]'",
        expected = {
            {type = "string", text = "'[test]'", line = 1, col = 1}
        }
    },
    {
        id = 1219,
        type = "tokenizer",
        name = "String with parentheses",
        input = "'(test)'",
        expected = {
            {type = "string", text = "'(test)'", line = 1, col = 1}
        }
    },
    {
        id = 1220,
        type = "tokenizer",
        name = "String with SQL keywords",
        input = "'SELECT FROM WHERE'",
        expected = {
            {type = "string", text = "'SELECT FROM WHERE'", line = 1, col = 1}
        }
    },

    -- Line comments (emitted as line_comment tokens)
    {
        id = 1221,
        type = "tokenizer",
        name = "Line comment at end - SELECT with comment",
        input = "SELECT -- comment",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "line_comment", text = "-- comment", line = 1, col = 8}
        }
    },
    {
        id = 1222,
        type = "tokenizer",
        name = "Line comment then newline and token",
        input = "SELECT -- comment\nFROM",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "line_comment", text = "-- comment", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 2, col = 1}
        }
    },
    {
        id = 1223,
        type = "tokenizer",
        name = "Line comment only",
        input = "-- this is a comment",
        expected = {
            {type = "line_comment", text = "-- this is a comment", line = 1, col = 1}
        }
    },
    {
        id = 1224,
        type = "tokenizer",
        name = "Multiple line comments",
        input = "-- comment 1\n-- comment 2\nSELECT",
        expected = {
            {type = "line_comment", text = "-- comment 1", line = 1, col = 1},
            {type = "line_comment", text = "-- comment 2", line = 2, col = 1},
            {type = "keyword", text = "SELECT", line = 3, col = 1}
        }
    },
    {
        id = 1225,
        type = "tokenizer",
        name = "Line comment at end of line",
        input = "SELECT * -- get all",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "line_comment", text = "-- get all", line = 1, col = 10}
        }
    },

    -- Block comments (emitted as comment tokens)
    {
        id = 1226,
        type = "tokenizer",
        name = "Simple block comment",
        input = "/* comment */",
        expected = {
            {type = "comment", text = "/* comment */", line = 1, col = 1}
        }
    },
    {
        id = 1227,
        type = "tokenizer",
        name = "Block comment between tokens",
        input = "SELECT /* comment */ FROM",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "comment", text = "/* comment */", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 22}
        }
    },
    {
        id = 1228,
        type = "tokenizer",
        name = "Multi-line block comment",
        input = "SELECT /*\ncomment\nhere\n*/ FROM",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "comment", text = "/*\ncomment\nhere\n*/", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 4, col = 4}
        }
    },
    {
        id = 1229,
        type = "tokenizer",
        name = "Multiple block comments",
        input = "SELECT /* c1 */ * /* c2 */ FROM",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "comment", text = "/* c1 */", line = 1, col = 8},
            {type = "star", text = "*", line = 1, col = 17},
            {type = "comment", text = "/* c2 */", line = 1, col = 19},
            {type = "keyword", text = "FROM", line = 1, col = 28}
        }
    },
    {
        id = 1230,
        type = "tokenizer",
        name = "Empty block comment",
        input = "SELECT /**/ FROM",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "comment", text = "/**/", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 13}
        }
    },

    -- Nested block comments (if supported)
    {
        id = 1231,
        type = "tokenizer",
        name = "Nested block comments",
        input = "SELECT /* outer /* inner */ still outer */ FROM",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "comment", text = "/* outer /* inner */ still outer */", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 44}
        }
    },

    -- Comments with special content
    {
        id = 1232,
        type = "tokenizer",
        name = "Line comment with SQL",
        input = "SELECT -- SELECT FROM WHERE",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "line_comment", text = "-- SELECT FROM WHERE", line = 1, col = 8}
        }
    },
    {
        id = 1233,
        type = "tokenizer",
        name = "Block comment with SQL",
        input = "SELECT /* SELECT FROM WHERE */ *",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "comment", text = "/* SELECT FROM WHERE */", line = 1, col = 8},
            {type = "star", text = "*", line = 1, col = 32}
        }
    },
    {
        id = 1234,
        type = "tokenizer",
        name = "Comment with special characters",
        input = "SELECT /* !@#$%^&*() */ FROM",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "comment", text = "/* !@#$%^&*() */", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 25}
        }
    },

    -- Mixed strings and comments
    {
        id = 1235,
        type = "tokenizer",
        name = "String before comment",
        input = "'hello' -- comment",
        expected = {
            {type = "string", text = "'hello'", line = 1, col = 1},
            {type = "line_comment", text = "-- comment", line = 1, col = 9}
        }
    },
    {
        id = 1236,
        type = "tokenizer",
        name = "String after comment on new line",
        input = "-- comment\n'hello'",
        expected = {
            {type = "line_comment", text = "-- comment", line = 1, col = 1},
            {type = "string", text = "'hello'", line = 2, col = 1}
        }
    },
    {
        id = 1237,
        type = "tokenizer",
        name = "String with comment-like content",
        input = "'-- not a comment'",
        expected = {
            {type = "string", text = "'-- not a comment'", line = 1, col = 1}
        }
    },
    {
        id = 1238,
        type = "tokenizer",
        name = "String with block comment-like content",
        input = "'/* not a comment */'",
        expected = {
            {type = "string", text = "'/* not a comment */'", line = 1, col = 1}
        }
    },
    {
        id = 1239,
        type = "tokenizer",
        name = "String between block comments",
        input = "/* c1 */ 'hello' /* c2 */",
        expected = {
            {type = "comment", text = "/* c1 */", line = 1, col = 1},
            {type = "string", text = "'hello'", line = 1, col = 10},
            {type = "comment", text = "/* c2 */", line = 1, col = 18}
        }
    },

    -- Edge cases
    {
        id = 1240,
        type = "tokenizer",
        name = "Line comment with no text after --",
        input = "SELECT --",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "line_comment", text = "--", line = 1, col = 8}
        }
    },
    {
        id = 1241,
        type = "tokenizer",
        name = "Line comment with only spaces",
        input = "SELECT --   \nFROM",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "line_comment", text = "--   ", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 2, col = 1}
        }
    },
    {
        id = 1242,
        type = "tokenizer",
        name = "Block comment with only spaces",
        input = "SELECT /*   */ FROM",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "comment", text = "/*   */", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 16}
        }
    },
    {
        id = 1243,
        type = "tokenizer",
        name = "Multiple consecutive line comments",
        input = "----",
        expected = {
            {type = "line_comment", text = "----", line = 1, col = 1}
        }
    },
    {
        id = 1244,
        type = "tokenizer",
        name = "Comment-like text in string preserves quotes",
        input = "'''--'''",
        expected = {
            {type = "string", text = "'''--'''", line = 1, col = 1}
        }
    },

    -- Long strings
    {
        id = 1245,
        type = "tokenizer",
        name = "Long string",
        input = "'This is a very long string with many words and characters in it'",
        expected = {
            {type = "string", text = "'This is a very long string with many words and characters in it'", line = 1, col = 1}
        }
    },

    -- Multi-line strings
    {
        id = 1246,
        type = "tokenizer",
        name = "String spanning multiple lines (if supported)",
        input = "'line1\nline2'",
        expected = {
            {type = "string", text = "'line1\nline2'", line = 1, col = 1}
        }
    },

    -- Real-world patterns
    {
        id = 1247,
        type = "tokenizer",
        name = "SQL with inline comment",
        input = "SELECT * FROM Users /* get all users */ WHERE Active = 1",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 8},
            {type = "keyword", text = "FROM", line = 1, col = 10},
            {type = "identifier", text = "Users", line = 1, col = 15},
            {type = "comment", text = "/* get all users */", line = 1, col = 21},
            {type = "keyword", text = "WHERE", line = 1, col = 41},
            {type = "identifier", text = "Active", line = 1, col = 47},
            {type = "operator", text = "=", line = 1, col = 54},
            {type = "number", text = "1", line = 1, col = 56}
        }
    },
    {
        id = 1248,
        type = "tokenizer",
        name = "SQL with end-of-line comments",
        input = "SELECT Id, -- primary key\n       Name -- user name",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "identifier", text = "Id", line = 1, col = 8},
            {type = "comma", text = ",", line = 1, col = 10},
            {type = "line_comment", text = "-- primary key", line = 1, col = 12},
            {type = "identifier", text = "Name", line = 2, col = 8},
            {type = "line_comment", text = "-- user name", line = 2, col = 13}
        }
    },
    {
        id = 1249,
        type = "tokenizer",
        name = "String with email address",
        input = "'user@example.com'",
        expected = {
            {type = "string", text = "'user@example.com'", line = 1, col = 1}
        }
    },
    {
        id = 1250,
        type = "tokenizer",
        name = "String with path",
        input = "'C:\\Users\\Documents\\file.txt'",
        expected = {
            {type = "string", text = "'C:\\Users\\Documents\\file.txt'", line = 1, col = 1}
        }
    },
}
