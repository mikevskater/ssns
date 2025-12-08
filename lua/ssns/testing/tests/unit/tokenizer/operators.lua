-- Test file: operators.lua
-- IDs: 1301-1350
-- Tests: Operator tokenization

return {
    -- Single character operators
    {
        id = 1301,
        type = "tokenizer",
        name = "Equals operator",
        input = "=",
        expected = {
            {type = "operator", text = "=", line = 1, col = 1}
        }
    },
    {
        id = 1302,
        type = "tokenizer",
        name = "Less than operator",
        input = "<",
        expected = {
            {type = "operator", text = "<", line = 1, col = 1}
        }
    },
    {
        id = 1303,
        type = "tokenizer",
        name = "Greater than operator",
        input = ">",
        expected = {
            {type = "operator", text = ">", line = 1, col = 1}
        }
    },
    {
        id = 1304,
        type = "tokenizer",
        name = "Plus operator",
        input = "+",
        expected = {
            {type = "operator", text = "+", line = 1, col = 1}
        }
    },
    {
        id = 1305,
        type = "tokenizer",
        name = "Minus operator",
        input = "-",
        expected = {
            {type = "operator", text = "-", line = 1, col = 1}
        }
    },
    {
        id = 1306,
        type = "tokenizer",
        name = "Asterisk operator (multiply)",
        input = "*",
        expected = {
            {type = "star", text = "*", line = 1, col = 1}
        }
    },
    {
        id = 1307,
        type = "tokenizer",
        name = "Forward slash operator (divide)",
        input = "/",
        expected = {
            {type = "operator", text = "/", line = 1, col = 1}
        }
    },
    {
        id = 1308,
        type = "tokenizer",
        name = "Modulo operator",
        input = "%",
        expected = {
            {type = "operator", text = "%", line = 1, col = 1}
        }
    },
    {
        id = 1309,
        type = "tokenizer",
        name = "Exclamation operator",
        input = "!",
        expected = {
            {type = "operator", text = "!", line = 1, col = 1}
        }
    },

    -- Multi-character comparison operators (emitted as single tokens)
    {
        id = 1310,
        type = "tokenizer",
        name = "Greater than or equal",
        input = ">=",
        expected = {
            {type = "operator", text = ">=", line = 1, col = 1}
        }
    },
    {
        id = 1311,
        type = "tokenizer",
        name = "Less than or equal",
        input = "<=",
        expected = {
            {type = "operator", text = "<=", line = 1, col = 1}
        }
    },
    {
        id = 1312,
        type = "tokenizer",
        name = "Not equal (angle brackets)",
        input = "<>",
        expected = {
            {type = "operator", text = "<>", line = 1, col = 1}
        }
    },
    {
        id = 1313,
        type = "tokenizer",
        name = "Not equal (exclamation)",
        input = "!=",
        expected = {
            {type = "operator", text = "!=", line = 1, col = 1}
        }
    },
    {
        id = 1314,
        type = "tokenizer",
        name = "Not less than",
        input = "!<",
        expected = {
            {type = "operator", text = "!", line = 1, col = 1},
            {type = "operator", text = "<", line = 1, col = 2}
        }
    },
    {
        id = 1315,
        type = "tokenizer",
        name = "Not greater than",
        input = "!>",
        expected = {
            {type = "operator", text = "!", line = 1, col = 1},
            {type = "operator", text = ">", line = 1, col = 2}
        }
    },

    -- Compound assignment operators (now emit as separate chars)
    {
        id = 1316,
        type = "tokenizer",
        name = "Plus equals",
        input = "+=",
        expected = {
            {type = "operator", text = "+", line = 1, col = 1},
            {type = "operator", text = "=", line = 1, col = 2}
        }
    },
    {
        id = 1317,
        type = "tokenizer",
        name = "Minus equals",
        input = "-=",
        expected = {
            {type = "operator", text = "-", line = 1, col = 1},
            {type = "operator", text = "=", line = 1, col = 2}
        }
    },
    {
        id = 1318,
        type = "tokenizer",
        name = "Multiply equals",
        input = "*=",
        expected = {
            {type = "star", text = "*", line = 1, col = 1},
            {type = "operator", text = "=", line = 1, col = 2}
        }
    },
    {
        id = 1319,
        type = "tokenizer",
        name = "Divide equals",
        input = "/=",
        expected = {
            {type = "operator", text = "/", line = 1, col = 1},
            {type = "operator", text = "=", line = 1, col = 2}
        }
    },
    {
        id = 1320,
        type = "tokenizer",
        name = "Modulo equals",
        input = "%=",
        expected = {
            {type = "operator", text = "%", line = 1, col = 1},
            {type = "operator", text = "=", line = 1, col = 2}
        }
    },
    {
        id = 1321,
        type = "tokenizer",
        name = "Bitwise AND equals",
        input = "&=",
        expected = {
            {type = "operator", text = "&", line = 1, col = 1},
            {type = "operator", text = "=", line = 1, col = 2}
        }
    },
    {
        id = 1322,
        type = "tokenizer",
        name = "Bitwise OR equals",
        input = "|=",
        expected = {
            {type = "operator", text = "|", line = 1, col = 1},
            {type = "operator", text = "=", line = 1, col = 2}
        }
    },
    {
        id = 1323,
        type = "tokenizer",
        name = "Bitwise XOR equals",
        input = "^=",
        expected = {
            {type = "operator", text = "^", line = 1, col = 1},
            {type = "operator", text = "=", line = 1, col = 2}
        }
    },

    -- Scope resolution operator (emitted as single token)
    {
        id = 1324,
        type = "tokenizer",
        name = "Scope resolution (double colon)",
        input = "::",
        expected = {
            {type = "operator", text = "::", line = 1, col = 1}
        }
    },

    -- Bitwise operators
    {
        id = 1325,
        type = "tokenizer",
        name = "Bitwise AND",
        input = "&",
        expected = {
            {type = "operator", text = "&", line = 1, col = 1}
        }
    },
    {
        id = 1326,
        type = "tokenizer",
        name = "Bitwise OR",
        input = "|",
        expected = {
            {type = "operator", text = "|", line = 1, col = 1}
        }
    },
    {
        id = 1327,
        type = "tokenizer",
        name = "Bitwise XOR",
        input = "^",
        expected = {
            {type = "operator", text = "^", line = 1, col = 1}
        }
    },
    {
        id = 1328,
        type = "tokenizer",
        name = "Bitwise NOT",
        input = "~",
        expected = {
            {type = "operator", text = "~", line = 1, col = 1}
        }
    },

    -- Operators in context
    {
        id = 1329,
        type = "tokenizer",
        name = "Equals in comparison",
        input = "a = b",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "operator", text = "=", line = 1, col = 3},
            {type = "identifier", text = "b", line = 1, col = 5}
        }
    },
    {
        id = 1330,
        type = "tokenizer",
        name = "Not equal in comparison",
        input = "a <> b",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "operator", text = "<>", line = 1, col = 3},
            {type = "identifier", text = "b", line = 1, col = 6}
        }
    },
    {
        id = 1331,
        type = "tokenizer",
        name = "Greater than or equal in comparison",
        input = "x >= 5",
        expected = {
            {type = "identifier", text = "x", line = 1, col = 1},
            {type = "operator", text = ">=", line = 1, col = 3},
            {type = "number", text = "5", line = 1, col = 6}
        }
    },
    {
        id = 1332,
        type = "tokenizer",
        name = "Less than or equal in comparison",
        input = "y <= 10",
        expected = {
            {type = "identifier", text = "y", line = 1, col = 1},
            {type = "operator", text = "<=", line = 1, col = 3},
            {type = "number", text = "10", line = 1, col = 6}
        }
    },
    {
        id = 1333,
        type = "tokenizer",
        name = "Addition expression",
        input = "a + b",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "operator", text = "+", line = 1, col = 3},
            {type = "identifier", text = "b", line = 1, col = 5}
        }
    },
    {
        id = 1334,
        type = "tokenizer",
        name = "Subtraction expression",
        input = "a - b",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "operator", text = "-", line = 1, col = 3},
            {type = "identifier", text = "b", line = 1, col = 5}
        }
    },
    {
        id = 1335,
        type = "tokenizer",
        name = "Multiplication expression",
        input = "a * b",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "star", text = "*", line = 1, col = 3},
            {type = "identifier", text = "b", line = 1, col = 5}
        }
    },
    {
        id = 1336,
        type = "tokenizer",
        name = "Division expression",
        input = "a / b",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "operator", text = "/", line = 1, col = 3},
            {type = "identifier", text = "b", line = 1, col = 5}
        }
    },
    {
        id = 1337,
        type = "tokenizer",
        name = "Modulo expression",
        input = "a % b",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "operator", text = "%", line = 1, col = 3},
            {type = "identifier", text = "b", line = 1, col = 5}
        }
    },

    -- Multiple operators
    {
        id = 1338,
        type = "tokenizer",
        name = "Complex arithmetic",
        input = "a + b * c",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "operator", text = "+", line = 1, col = 3},
            {type = "identifier", text = "b", line = 1, col = 5},
            {type = "star", text = "*", line = 1, col = 7},
            {type = "identifier", text = "c", line = 1, col = 9}
        }
    },
    {
        id = 1339,
        type = "tokenizer",
        name = "Chained comparisons",
        input = "a > b AND c < d",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "operator", text = ">", line = 1, col = 3},
            {type = "identifier", text = "b", line = 1, col = 5},
            {type = "keyword", text = "AND", line = 1, col = 7},
            {type = "identifier", text = "c", line = 1, col = 11},
            {type = "operator", text = "<", line = 1, col = 13},
            {type = "identifier", text = "d", line = 1, col = 15}
        }
    },

    -- Operators without spaces
    {
        id = 1340,
        type = "tokenizer",
        name = "Operators without spaces - equals",
        input = "a=b",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "operator", text = "=", line = 1, col = 2},
            {type = "identifier", text = "b", line = 1, col = 3}
        }
    },
    {
        id = 1341,
        type = "tokenizer",
        name = "Operators without spaces - not equal",
        input = "a<>b",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "operator", text = "<>", line = 1, col = 2},
            {type = "identifier", text = "b", line = 1, col = 4}
        }
    },
    {
        id = 1342,
        type = "tokenizer",
        name = "Operators without spaces - addition",
        input = "a+b",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "operator", text = "+", line = 1, col = 2},
            {type = "identifier", text = "b", line = 1, col = 3}
        }
    },

    -- Compound assignment in context
    {
        id = 1343,
        type = "tokenizer",
        name = "Plus equals assignment",
        input = "SET x += 5",
        expected = {
            {type = "keyword", text = "SET", line = 1, col = 1},
            {type = "identifier", text = "x", line = 1, col = 5},
            {type = "operator", text = "+", line = 1, col = 7},
            {type = "operator", text = "=", line = 1, col = 8},
            {type = "number", text = "5", line = 1, col = 10}
        }
    },
    {
        id = 1344,
        type = "tokenizer",
        name = "Minus equals assignment",
        input = "SET y -= 3",
        expected = {
            {type = "keyword", text = "SET", line = 1, col = 1},
            {type = "identifier", text = "y", line = 1, col = 5},
            {type = "operator", text = "-", line = 1, col = 7},
            {type = "operator", text = "=", line = 1, col = 8},
            {type = "number", text = "3", line = 1, col = 10}
        }
    },

    -- Edge cases
    {
        id = 1345,
        type = "tokenizer",
        name = "Negative number (minus is operator)",
        input = "-5",
        expected = {
            {type = "operator", text = "-", line = 1, col = 1},
            {type = "number", text = "5", line = 1, col = 2}
        }
    },
    {
        id = 1346,
        type = "tokenizer",
        name = "Positive number (plus is operator)",
        input = "+5",
        expected = {
            {type = "operator", text = "+", line = 1, col = 1},
            {type = "number", text = "5", line = 1, col = 2}
        }
    },
    {
        id = 1347,
        type = "tokenizer",
        name = "Multiple consecutive operators",
        input = "+-",
        expected = {
            {type = "operator", text = "+", line = 1, col = 1},
            {type = "operator", text = "-", line = 1, col = 2}
        }
    },
    {
        id = 1348,
        type = "tokenizer",
        name = "Scope resolution with identifiers",
        input = "dbo::table",
        expected = {
            {type = "identifier", text = "dbo", line = 1, col = 1},
            {type = "operator", text = "::", line = 1, col = 4},
            {type = "keyword", text = "table", line = 1, col = 6}
        }
    },
    {
        id = 1349,
        type = "tokenizer",
        name = "Bitwise operators in expression",
        input = "a & b | c",
        expected = {
            {type = "identifier", text = "a", line = 1, col = 1},
            {type = "operator", text = "&", line = 1, col = 3},
            {type = "identifier", text = "b", line = 1, col = 5},
            {type = "operator", text = "|", line = 1, col = 7},
            {type = "identifier", text = "c", line = 1, col = 9}
        }
    },
    {
        id = 1350,
        type = "tokenizer",
        name = "All operators in sequence",
        input = "= < > + - * / % ! >= <= <> != !< !> += -= *= /= %= :: & | ^ ~",
        expected = {
            {type = "operator", text = "=", line = 1, col = 1},
            {type = "operator", text = "<", line = 1, col = 3},
            {type = "operator", text = ">", line = 1, col = 5},
            {type = "operator", text = "+", line = 1, col = 7},
            {type = "operator", text = "-", line = 1, col = 9},
            {type = "star", text = "*", line = 1, col = 11},
            {type = "operator", text = "/", line = 1, col = 13},
            {type = "operator", text = "%", line = 1, col = 15},
            {type = "operator", text = "!", line = 1, col = 17},
            {type = "operator", text = ">=", line = 1, col = 19},
            {type = "operator", text = "<=", line = 1, col = 22},
            {type = "operator", text = "<>", line = 1, col = 25},
            {type = "operator", text = "!=", line = 1, col = 28},
            {type = "operator", text = "!", line = 1, col = 31},
            {type = "operator", text = "<", line = 1, col = 32},
            {type = "operator", text = "!", line = 1, col = 34},
            {type = "operator", text = ">", line = 1, col = 35},
            {type = "operator", text = "+", line = 1, col = 37},
            {type = "operator", text = "=", line = 1, col = 38},
            {type = "operator", text = "-", line = 1, col = 40},
            {type = "operator", text = "=", line = 1, col = 41},
            {type = "star", text = "*", line = 1, col = 43},
            {type = "operator", text = "=", line = 1, col = 44},
            {type = "operator", text = "/", line = 1, col = 46},
            {type = "operator", text = "=", line = 1, col = 47},
            {type = "operator", text = "%", line = 1, col = 49},
            {type = "operator", text = "=", line = 1, col = 50},
            {type = "operator", text = "::", line = 1, col = 52},
            {type = "operator", text = "&", line = 1, col = 55},
            {type = "operator", text = "|", line = 1, col = 57},
            {type = "operator", text = "^", line = 1, col = 59},
            {type = "operator", text = "~", line = 1, col = 61}
        }
    },
}
