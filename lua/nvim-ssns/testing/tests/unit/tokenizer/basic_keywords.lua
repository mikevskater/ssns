-- Test file: basic_keywords.lua
-- IDs: 1001-1050
-- Tests: SQL keyword tokenization

return {
    -- SELECT statement keywords
    {
        id = 1001,
        type = "tokenizer",
        name = "SELECT keyword",
        input = "SELECT",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1}
        }
    },
    {
        id = 1002,
        type = "tokenizer",
        name = "FROM keyword",
        input = "FROM",
        expected = {
            {type = "keyword", text = "FROM", line = 1, col = 1}
        }
    },
    {
        id = 1003,
        type = "tokenizer",
        name = "WHERE keyword",
        input = "WHERE",
        expected = {
            {type = "keyword", text = "WHERE", line = 1, col = 1}
        }
    },

    -- JOIN keywords
    {
        id = 1004,
        type = "tokenizer",
        name = "JOIN keyword",
        input = "JOIN",
        expected = {
            {type = "keyword", text = "JOIN", line = 1, col = 1}
        }
    },
    {
        id = 1005,
        type = "tokenizer",
        name = "INNER keyword",
        input = "INNER",
        expected = {
            {type = "keyword", text = "INNER", line = 1, col = 1}
        }
    },
    {
        id = 1006,
        type = "tokenizer",
        name = "LEFT keyword",
        input = "LEFT",
        expected = {
            {type = "keyword", text = "LEFT", line = 1, col = 1}
        }
    },
    {
        id = 1007,
        type = "tokenizer",
        name = "RIGHT keyword",
        input = "RIGHT",
        expected = {
            {type = "keyword", text = "RIGHT", line = 1, col = 1}
        }
    },
    {
        id = 1008,
        type = "tokenizer",
        name = "OUTER keyword",
        input = "OUTER",
        expected = {
            {type = "keyword", text = "OUTER", line = 1, col = 1}
        }
    },
    {
        id = 1009,
        type = "tokenizer",
        name = "FULL keyword",
        input = "FULL",
        expected = {
            {type = "keyword", text = "FULL", line = 1, col = 1}
        }
    },
    {
        id = 1010,
        type = "tokenizer",
        name = "CROSS keyword",
        input = "CROSS",
        expected = {
            {type = "keyword", text = "CROSS", line = 1, col = 1}
        }
    },

    -- Conditional keywords
    {
        id = 1011,
        type = "tokenizer",
        name = "ON keyword",
        input = "ON",
        expected = {
            {type = "keyword", text = "ON", line = 1, col = 1}
        }
    },
    {
        id = 1012,
        type = "tokenizer",
        name = "AND keyword",
        input = "AND",
        expected = {
            {type = "keyword", text = "AND", line = 1, col = 1}
        }
    },
    {
        id = 1013,
        type = "tokenizer",
        name = "OR keyword",
        input = "OR",
        expected = {
            {type = "keyword", text = "OR", line = 1, col = 1}
        }
    },
    {
        id = 1014,
        type = "tokenizer",
        name = "NOT keyword",
        input = "NOT",
        expected = {
            {type = "keyword", text = "NOT", line = 1, col = 1}
        }
    },
    {
        id = 1015,
        type = "tokenizer",
        name = "IN keyword",
        input = "IN",
        expected = {
            {type = "keyword", text = "IN", line = 1, col = 1}
        }
    },
    {
        id = 1016,
        type = "tokenizer",
        name = "EXISTS keyword",
        input = "EXISTS",
        expected = {
            {type = "keyword", text = "EXISTS", line = 1, col = 1}
        }
    },
    {
        id = 1017,
        type = "tokenizer",
        name = "BETWEEN keyword",
        input = "BETWEEN",
        expected = {
            {type = "keyword", text = "BETWEEN", line = 1, col = 1}
        }
    },
    {
        id = 1018,
        type = "tokenizer",
        name = "LIKE keyword",
        input = "LIKE",
        expected = {
            {type = "keyword", text = "LIKE", line = 1, col = 1}
        }
    },
    {
        id = 1019,
        type = "tokenizer",
        name = "IS keyword",
        input = "IS",
        expected = {
            {type = "keyword", text = "IS", line = 1, col = 1}
        }
    },
    {
        id = 1020,
        type = "tokenizer",
        name = "NULL keyword",
        input = "NULL",
        expected = {
            {type = "keyword", text = "NULL", line = 1, col = 1}
        }
    },

    -- Alias and insert keywords
    {
        id = 1021,
        type = "tokenizer",
        name = "AS keyword",
        input = "AS",
        expected = {
            {type = "keyword", text = "AS", line = 1, col = 1}
        }
    },
    {
        id = 1022,
        type = "tokenizer",
        name = "INTO keyword",
        input = "INTO",
        expected = {
            {type = "keyword", text = "INTO", line = 1, col = 1}
        }
    },
    {
        id = 1023,
        type = "tokenizer",
        name = "INSERT keyword",
        input = "INSERT",
        expected = {
            {type = "keyword", text = "INSERT", line = 1, col = 1}
        }
    },
    {
        id = 1024,
        type = "tokenizer",
        name = "UPDATE keyword",
        input = "UPDATE",
        expected = {
            {type = "keyword", text = "UPDATE", line = 1, col = 1}
        }
    },
    {
        id = 1025,
        type = "tokenizer",
        name = "DELETE keyword",
        input = "DELETE",
        expected = {
            {type = "keyword", text = "DELETE", line = 1, col = 1}
        }
    },

    -- DDL keywords
    {
        id = 1026,
        type = "tokenizer",
        name = "CREATE keyword",
        input = "CREATE",
        expected = {
            {type = "keyword", text = "CREATE", line = 1, col = 1}
        }
    },
    {
        id = 1027,
        type = "tokenizer",
        name = "ALTER keyword",
        input = "ALTER",
        expected = {
            {type = "keyword", text = "ALTER", line = 1, col = 1}
        }
    },
    {
        id = 1028,
        type = "tokenizer",
        name = "DROP keyword",
        input = "DROP",
        expected = {
            {type = "keyword", text = "DROP", line = 1, col = 1}
        }
    },
    {
        id = 1029,
        type = "tokenizer",
        name = "TABLE keyword",
        input = "TABLE",
        expected = {
            {type = "keyword", text = "TABLE", line = 1, col = 1}
        }
    },

    -- Set operations and ordering
    {
        id = 1030,
        type = "tokenizer",
        name = "WITH keyword",
        input = "WITH",
        expected = {
            {type = "keyword", text = "WITH", line = 1, col = 1}
        }
    },
    {
        id = 1031,
        type = "tokenizer",
        name = "UNION keyword",
        input = "UNION",
        expected = {
            {type = "keyword", text = "UNION", line = 1, col = 1}
        }
    },
    {
        id = 1032,
        type = "tokenizer",
        name = "INTERSECT keyword",
        input = "INTERSECT",
        expected = {
            {type = "keyword", text = "INTERSECT", line = 1, col = 1}
        }
    },
    {
        id = 1033,
        type = "tokenizer",
        name = "EXCEPT keyword",
        input = "EXCEPT",
        expected = {
            {type = "keyword", text = "EXCEPT", line = 1, col = 1}
        }
    },
    {
        id = 1034,
        type = "tokenizer",
        name = "ORDER keyword",
        input = "ORDER",
        expected = {
            {type = "keyword", text = "ORDER", line = 1, col = 1}
        }
    },
    {
        id = 1035,
        type = "tokenizer",
        name = "BY keyword",
        input = "BY",
        expected = {
            {type = "keyword", text = "BY", line = 1, col = 1}
        }
    },
    {
        id = 1036,
        type = "tokenizer",
        name = "GROUP keyword",
        input = "GROUP",
        expected = {
            {type = "keyword", text = "GROUP", line = 1, col = 1}
        }
    },
    {
        id = 1037,
        type = "tokenizer",
        name = "HAVING keyword",
        input = "HAVING",
        expected = {
            {type = "keyword", text = "HAVING", line = 1, col = 1}
        }
    },

    -- Modifiers
    {
        id = 1038,
        type = "tokenizer",
        name = "TOP keyword",
        input = "TOP",
        expected = {
            {type = "keyword", text = "TOP", line = 1, col = 1}
        }
    },
    {
        id = 1039,
        type = "tokenizer",
        name = "DISTINCT keyword",
        input = "DISTINCT",
        expected = {
            {type = "keyword", text = "DISTINCT", line = 1, col = 1}
        }
    },
    {
        id = 1040,
        type = "tokenizer",
        name = "ALL keyword",
        input = "ALL",
        expected = {
            {type = "keyword", text = "ALL", line = 1, col = 1}
        }
    },

    -- CASE expression
    {
        id = 1041,
        type = "tokenizer",
        name = "CASE keyword",
        input = "CASE",
        expected = {
            {type = "keyword", text = "CASE", line = 1, col = 1}
        }
    },
    {
        id = 1042,
        type = "tokenizer",
        name = "WHEN keyword",
        input = "WHEN",
        expected = {
            {type = "keyword", text = "WHEN", line = 1, col = 1}
        }
    },
    {
        id = 1043,
        type = "tokenizer",
        name = "THEN keyword",
        input = "THEN",
        expected = {
            {type = "keyword", text = "THEN", line = 1, col = 1}
        }
    },
    {
        id = 1044,
        type = "tokenizer",
        name = "ELSE keyword",
        input = "ELSE",
        expected = {
            {type = "keyword", text = "ELSE", line = 1, col = 1}
        }
    },
    {
        id = 1045,
        type = "tokenizer",
        name = "END keyword",
        input = "END",
        expected = {
            {type = "keyword", text = "END", line = 1, col = 1}
        }
    },

    -- Procedural keywords
    {
        id = 1046,
        type = "tokenizer",
        name = "DECLARE keyword",
        input = "DECLARE",
        expected = {
            {type = "keyword", text = "DECLARE", line = 1, col = 1}
        }
    },
    {
        id = 1047,
        type = "tokenizer",
        name = "SET keyword",
        input = "SET",
        expected = {
            {type = "keyword", text = "SET", line = 1, col = 1}
        }
    },
    {
        id = 1048,
        type = "tokenizer",
        name = "EXEC keyword",
        input = "EXEC",
        expected = {
            {type = "keyword", text = "EXEC", line = 1, col = 1}
        }
    },
    {
        id = 1049,
        type = "tokenizer",
        name = "EXECUTE keyword",
        input = "EXECUTE",
        expected = {
            {type = "keyword", text = "EXECUTE", line = 1, col = 1}
        }
    },
    {
        id = 1050,
        type = "tokenizer",
        name = "BEGIN keyword",
        input = "BEGIN",
        expected = {
            {type = "keyword", text = "BEGIN", line = 1, col = 1}
        }
    },
}
