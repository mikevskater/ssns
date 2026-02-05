-- Test file: identifiers.lua
-- IDs: 1101-1150
-- Tests: Identifier tokenization

return {
    -- Simple identifiers
    {
        id = 1101,
        type = "tokenizer",
        name = "Simple identifier - Employees",
        input = "Employees",
        expected = {
            {type = "identifier", text = "Employees", line = 1, col = 1}
        }
    },
    {
        id = 1102,
        type = "tokenizer",
        name = "Simple identifier - firstName",
        input = "firstName",
        expected = {
            {type = "identifier", text = "firstName", line = 1, col = 1}
        }
    },
    {
        id = 1103,
        type = "tokenizer",
        name = "Simple identifier - table1",
        input = "table1",
        expected = {
            {type = "identifier", text = "table1", line = 1, col = 1}
        }
    },
    {
        id = 1104,
        type = "tokenizer",
        name = "Simple identifier - lowercase",
        input = "users",
        expected = {
            {type = "identifier", text = "users", line = 1, col = 1}
        }
    },
    {
        id = 1105,
        type = "tokenizer",
        name = "Simple identifier - UPPERCASE",
        input = "CUSTOMERS",
        expected = {
            {type = "identifier", text = "CUSTOMERS", line = 1, col = 1}
        }
    },
    {
        id = 1106,
        type = "tokenizer",
        name = "Simple identifier - MixedCase",
        input = "MyTable",
        expected = {
            {type = "identifier", text = "MyTable", line = 1, col = 1}
        }
    },

    -- Bracketed identifiers (simple)
    {
        id = 1107,
        type = "tokenizer",
        name = "Bracketed identifier - simple",
        input = "[TableName]",
        expected = {
            {type = "bracket_id", text = "[TableName]", line = 1, col = 1}
        }
    },
    {
        id = 1108,
        type = "tokenizer",
        name = "Bracketed identifier - with space",
        input = "[My Table]",
        expected = {
            {type = "bracket_id", text = "[My Table]", line = 1, col = 1}
        }
    },
    {
        id = 1109,
        type = "tokenizer",
        name = "Bracketed identifier - with spaces",
        input = "[Column Name]",
        expected = {
            {type = "bracket_id", text = "[Column Name]", line = 1, col = 1}
        }
    },
    {
        id = 1110,
        type = "tokenizer",
        name = "Bracketed identifier - schema",
        input = "[schema]",
        expected = {
            {type = "bracket_id", text = "[schema]", line = 1, col = 1}
        }
    },
    {
        id = 1111,
        type = "tokenizer",
        name = "Bracketed identifier - with numbers",
        input = "[Table123]",
        expected = {
            {type = "bracket_id", text = "[Table123]", line = 1, col = 1}
        }
    },
    {
        id = 1112,
        type = "tokenizer",
        name = "Bracketed identifier - reserved word",
        input = "[SELECT]",
        expected = {
            {type = "bracket_id", text = "[SELECT]", line = 1, col = 1}
        }
    },
    {
        id = 1113,
        type = "tokenizer",
        name = "Bracketed identifier - with hyphen",
        input = "[My-Table]",
        expected = {
            {type = "bracket_id", text = "[My-Table]", line = 1, col = 1}
        }
    },
    {
        id = 1114,
        type = "tokenizer",
        name = "Bracketed identifier - with underscore",
        input = "[My_Table]",
        expected = {
            {type = "bracket_id", text = "[My_Table]", line = 1, col = 1}
        }
    },

    -- Temp tables (emitted as single temp_table token)
    {
        id = 1115,
        type = "tokenizer",
        name = "Temp table - local",
        input = "#TempTable",
        expected = {
            {type = "temp_table", text = "#TempTable", line = 1, col = 1}
        }
    },
    {
        id = 1116,
        type = "tokenizer",
        name = "Temp table - local lowercase",
        input = "#temp",
        expected = {
            {type = "temp_table", text = "#temp", line = 1, col = 1}
        }
    },
    {
        id = 1117,
        type = "tokenizer",
        name = "Temp table - global",
        input = "##GlobalTemp",
        expected = {
            {type = "temp_table", text = "##GlobalTemp", line = 1, col = 1}
        }
    },
    {
        id = 1118,
        type = "tokenizer",
        name = "Temp table - global lowercase",
        input = "##global",
        expected = {
            {type = "temp_table", text = "##global", line = 1, col = 1}
        }
    },
    {
        id = 1119,
        type = "tokenizer",
        name = "Temp table - with numbers",
        input = "#Temp123",
        expected = {
            {type = "temp_table", text = "#Temp123", line = 1, col = 1}
        }
    },
    {
        id = 1120,
        type = "tokenizer",
        name = "Temp table - with underscore",
        input = "#Temp_Data",
        expected = {
            {type = "temp_table", text = "#Temp_Data", line = 1, col = 1}
        }
    },

    -- Identifiers with numbers
    {
        id = 1121,
        type = "tokenizer",
        name = "Identifier with numbers - Table123",
        input = "Table123",
        expected = {
            {type = "identifier", text = "Table123", line = 1, col = 1}
        }
    },
    {
        id = 1122,
        type = "tokenizer",
        name = "Identifier with numbers - col1",
        input = "col1",
        expected = {
            {type = "identifier", text = "col1", line = 1, col = 1}
        }
    },
    {
        id = 1123,
        type = "tokenizer",
        name = "Identifier with numbers - t1",
        input = "t1",
        expected = {
            {type = "identifier", text = "t1", line = 1, col = 1}
        }
    },
    {
        id = 1124,
        type = "tokenizer",
        name = "Identifier with numbers - field99",
        input = "field99",
        expected = {
            {type = "identifier", text = "field99", line = 1, col = 1}
        }
    },

    -- Identifiers with underscore
    {
        id = 1125,
        type = "tokenizer",
        name = "Identifier starting with underscore",
        input = "_private",
        expected = {
            {type = "identifier", text = "_private", line = 1, col = 1}
        }
    },
    {
        id = 1126,
        type = "tokenizer",
        name = "Identifier with underscore in middle",
        input = "user_id",
        expected = {
            {type = "identifier", text = "user_id", line = 1, col = 1}
        }
    },
    {
        id = 1127,
        type = "tokenizer",
        name = "Identifier with multiple underscores",
        input = "first_name_value",
        expected = {
            {type = "identifier", text = "first_name_value", line = 1, col = 1}
        }
    },
    {
        id = 1128,
        type = "tokenizer",
        name = "Identifier ending with underscore",
        input = "column_",
        expected = {
            {type = "identifier", text = "column_", line = 1, col = 1}
        }
    },
    {
        id = 1129,
        type = "tokenizer",
        name = "Identifier only underscore (edge case)",
        input = "_",
        expected = {
            {type = "identifier", text = "_", line = 1, col = 1}
        }
    },
    {
        id = 1130,
        type = "tokenizer",
        name = "Identifier double underscore",
        input = "__internal",
        expected = {
            {type = "identifier", text = "__internal", line = 1, col = 1}
        }
    },

    -- Case preservation
    {
        id = 1131,
        type = "tokenizer",
        name = "Case preservation - MyTable",
        input = "MyTable",
        expected = {
            {type = "identifier", text = "MyTable", line = 1, col = 1}
        }
    },
    {
        id = 1132,
        type = "tokenizer",
        name = "Case preservation - myTABLE",
        input = "myTABLE",
        expected = {
            {type = "identifier", text = "myTABLE", line = 1, col = 1}
        }
    },
    {
        id = 1133,
        type = "tokenizer",
        name = "Case preservation - MYTABLE",
        input = "MYTABLE",
        expected = {
            {type = "identifier", text = "MYTABLE", line = 1, col = 1}
        }
    },
    {
        id = 1134,
        type = "tokenizer",
        name = "Case preservation - mytable",
        input = "mytable",
        expected = {
            {type = "identifier", text = "mytable", line = 1, col = 1}
        }
    },

    -- Mixed scenarios
    {
        id = 1135,
        type = "tokenizer",
        name = "Identifier with all valid chars",
        input = "_Table123_Name",
        expected = {
            {type = "identifier", text = "_Table123_Name", line = 1, col = 1}
        }
    },
    {
        id = 1136,
        type = "tokenizer",
        name = "Long identifier",
        input = "VeryLongTableNameWithManyCharacters",
        expected = {
            {type = "identifier", text = "VeryLongTableNameWithManyCharacters", line = 1, col = 1}
        }
    },
    {
        id = 1137,
        type = "tokenizer",
        name = "Single letter identifier",
        input = "a",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1}
        }
    },
    {
        id = 1138,
        type = "tokenizer",
        name = "Single letter uppercase identifier",
        input = "T",
        expected = {
            {type = "identifier", text = "T", line = 1, col = 1}
        }
    },

    -- Identifiers in context (multiple tokens)
    {
        id = 1139,
        type = "tokenizer",
        name = "Two identifiers separated by space",
        input = "table1 table2",
        expected = {
            {type = "identifier", text = "table1", line = 1, col = 1},
            {type = "identifier", text = "table2", line = 1, col = 8}
        }
    },
    {
        id = 1140,
        type = "tokenizer",
        name = "Identifier and bracketed identifier",
        input = "schema.[Table Name]",
        expected = {
            {type = "keyword", text = "schema", line = 1, col = 1},
            {type = "dot", text = ".", line = 1, col = 7},
            {type = "bracket_id", text = "[Table Name]", line = 1, col = 8}
        }
    },

    -- Edge cases with brackets
    {
        id = 1141,
        type = "tokenizer",
        name = "Empty brackets (edge case)",
        input = "[]",
        expected = {
            {type = "bracket_id", text = "[]", line = 1, col = 1}
        }
    },
    {
        id = 1142,
        type = "tokenizer",
        name = "Bracketed identifier with only space",
        input = "[ ]",
        expected = {
            {type = "bracket_id", text = "[ ]", line = 1, col = 1}
        }
    },
    {
        id = 1143,
        type = "tokenizer",
        name = "Bracketed identifier with special chars",
        input = "[Table@Name!]",
        expected = {
            {type = "bracket_id", text = "[Table@Name!]", line = 1, col = 1}
        }
    },
    {
        id = 1144,
        type = "tokenizer",
        name = "Bracketed identifier with dot",
        input = "[Table.Name]",
        expected = {
            {type = "bracket_id", text = "[Table.Name]", line = 1, col = 1}
        }
    },
    {
        id = 1145,
        type = "tokenizer",
        name = "User variable with @ prefix",
        input = "@variable",
        expected = {
            -- User variables are emitted as single variable tokens
            {type = "variable", text = "@variable", line = 1, col = 1}
        }
    },
    {
        id = 1146,
        type = "tokenizer",
        name = "Identifier with @@ prefix (global variable)",
        input = "@@IDENTITY",
        expected = {
            -- Global variables are emitted as a single token
            {type = "global_variable", text = "@@IDENTITY", line = 1, col = 1}
        }
    },

    -- Additional common patterns
    {
        id = 1147,
        type = "tokenizer",
        name = "CamelCase identifier",
        input = "getUserDetails",
        expected = {
            {type = "identifier", text = "getUserDetails", line = 1, col = 1}
        }
    },
    {
        id = 1148,
        type = "tokenizer",
        name = "PascalCase identifier",
        input = "GetUserDetails",
        expected = {
            {type = "identifier", text = "GetUserDetails", line = 1, col = 1}
        }
    },
    {
        id = 1149,
        type = "tokenizer",
        name = "snake_case identifier",
        input = "get_user_details",
        expected = {
            {type = "identifier", text = "get_user_details", line = 1, col = 1}
        }
    },
    {
        id = 1150,
        type = "tokenizer",
        name = "SCREAMING_SNAKE_CASE identifier",
        input = "MAX_USER_COUNT",
        expected = {
            {type = "identifier", text = "MAX_USER_COUNT", line = 1, col = 1}
        }
    },
}
