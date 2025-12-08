-- Test file: numbers.lua
-- IDs: 1451-1480
-- Tests: Number tokenization

return {
    -- Integers
    {
        id = 1451,
        type = "tokenizer",
        name = "Single digit integer",
        input = "5",
        expected = {
            {type = "number", text = "5", line = 1, col = 1}
        }
    },
    {
        id = 1452,
        type = "tokenizer",
        name = "Zero",
        input = "0",
        expected = {
            {type = "number", text = "0", line = 1, col = 1}
        }
    },
    {
        id = 1453,
        type = "tokenizer",
        name = "Two digit integer",
        input = "42",
        expected = {
            {type = "number", text = "42", line = 1, col = 1}
        }
    },
    {
        id = 1454,
        type = "tokenizer",
        name = "Three digit integer",
        input = "123",
        expected = {
            {type = "number", text = "123", line = 1, col = 1}
        }
    },
    {
        id = 1455,
        type = "tokenizer",
        name = "Large integer",
        input = "999999",
        expected = {
            {type = "number", text = "999999", line = 1, col = 1}
        }
    },
    {
        id = 1456,
        type = "tokenizer",
        name = "Very large integer",
        input = "1234567890",
        expected = {
            {type = "number", text = "1234567890", line = 1, col = 1}
        }
    },

    -- Decimals (emitted as single number tokens)
    {
        id = 1457,
        type = "tokenizer",
        name = "Simple decimal",
        input = "12.34",
        expected = {
            {type = "number", text = "12.34", line = 1, col = 1}
        }
    },
    {
        id = 1458,
        type = "tokenizer",
        name = "Decimal with zero integer part",
        input = "0.5",
        expected = {
            {type = "number", text = "0.5", line = 1, col = 1}
        }
    },
    {
        id = 1459,
        type = "tokenizer",
        name = "Decimal starting with dot",
        input = ".5",
        expected = {
            {type = "number", text = ".5", line = 1, col = 1}
        }
    },
    {
        id = 1460,
        type = "tokenizer",
        name = "Decimal with multiple digits",
        input = "123.456",
        expected = {
            {type = "number", text = "123.456", line = 1, col = 1}
        }
    },
    {
        id = 1461,
        type = "tokenizer",
        name = "Decimal ending in zero",
        input = "5.0",
        expected = {
            {type = "number", text = "5.0", line = 1, col = 1}
        }
    },
    {
        id = 1462,
        type = "tokenizer",
        name = "Decimal with many decimal places",
        input = "3.141592653589793",
        expected = {
            {type = "number", text = "3.141592653589793", line = 1, col = 1}
        }
    },
    {
        id = 1463,
        type = "tokenizer",
        name = "Zero point zero",
        input = "0.0",
        expected = {
            {type = "number", text = "0.0", line = 1, col = 1}
        }
    },

    -- Negative numbers (emitted as single number tokens at start of input/after operators)
    {
        id = 1464,
        type = "tokenizer",
        name = "Negative integer",
        input = "-5",
        expected = {
            {type = "number", text = "-5", line = 1, col = 1}
        }
    },
    {
        id = 1465,
        type = "tokenizer",
        name = "Negative decimal",
        input = "-12.34",
        expected = {
            {type = "number", text = "-12.34", line = 1, col = 1}
        }
    },
    {
        id = 1466,
        type = "tokenizer",
        name = "Negative zero",
        input = "-0",
        expected = {
            {type = "number", text = "-0", line = 1, col = 1}
        }
    },

    -- Positive numbers (plus is still an operator, number is a single token)
    {
        id = 1467,
        type = "tokenizer",
        name = "Positive integer (plus + number)",
        input = "+5",
        expected = {
            {type = "operator", text = "+", line = 1, col = 1},
            {type = "number", text = "5", line = 1, col = 2}
        }
    },
    {
        id = 1468,
        type = "tokenizer",
        name = "Positive decimal (plus + number)",
        input = "+12.34",
        expected = {
            {type = "operator", text = "+", line = 1, col = 1},
            {type = "number", text = "12.34", line = 1, col = 2}
        }
    },

    -- Numbers in context
    {
        id = 1469,
        type = "tokenizer",
        name = "Number in comparison",
        input = "x = 5",
        expected = {
            {type = "identifier", text = "x", line = 1, col = 1},
            {type = "operator", text = "=", line = 1, col = 3},
            {type = "number", text = "5", line = 1, col = 5}
        }
    },
    {
        id = 1470,
        type = "tokenizer",
        name = "Number in SELECT",
        input = "SELECT 1",
        expected = {
            {type = "keyword", text = "SELECT", line = 1, col = 1},
            {type = "number", text = "1", line = 1, col = 8}
        }
    },
    {
        id = 1471,
        type = "tokenizer",
        name = "Multiple numbers",
        input = "1 2 3",
        expected = {
            {type = "number", text = "1", line = 1, col = 1},
            {type = "number", text = "2", line = 1, col = 3},
            {type = "number", text = "3", line = 1, col = 5}
        }
    },
    {
        id = 1472,
        type = "tokenizer",
        name = "Numbers with commas",
        input = "1, 2, 3",
        expected = {
            {type = "number", text = "1", line = 1, col = 1},
            {type = "comma", text = ",", line = 1, col = 2},
            {type = "number", text = "2", line = 1, col = 4},
            {type = "comma", text = ",", line = 1, col = 5},
            {type = "number", text = "3", line = 1, col = 7}
        }
    },
    {
        id = 1473,
        type = "tokenizer",
        name = "Number in IN clause",
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
        id = 1474,
        type = "tokenizer",
        name = "Number in arithmetic",
        input = "5 + 3",
        expected = {
            {type = "number", text = "5", line = 1, col = 1},
            {type = "operator", text = "+", line = 1, col = 3},
            {type = "number", text = "3", line = 1, col = 5}
        }
    },
    {
        id = 1475,
        type = "tokenizer",
        name = "Decimal in arithmetic",
        input = "10.5 - 2.3",
        expected = {
            {type = "number", text = "10.5", line = 1, col = 1},
            {type = "operator", text = "-", line = 1, col = 6},
            {type = "number", text = "2.3", line = 1, col = 8}
        }
    },

    -- Edge cases
    {
        id = 1476,
        type = "tokenizer",
        name = "Number followed by identifier",
        input = "5a",
        expected = {
            {type = "identifier", text = "5a", line = 1, col = 1}
        }
    },
    {
        id = 1477,
        type = "tokenizer",
        name = "Number without space before identifier",
        input = "123table",
        expected = {
            {type = "identifier", text = "123table", line = 1, col = 1}
        }
    },
    {
        id = 1478,
        type = "tokenizer",
        name = "Decimal without trailing digits",
        input = "5.",
        expected = {
            {type = "number", text = "5", line = 1, col = 1},
            {type = "dot", text = ".", line = 1, col = 2}
        }
    },
    {
        id = 1479,
        type = "tokenizer",
        name = "Multiple decimals (second dot is member access)",
        input = "3.14.159",
        expected = {
            {type = "number", text = "3.14", line = 1, col = 1},
            {type = "dot", text = ".", line = 1, col = 5},
            {type = "number", text = "159", line = 1, col = 6}
        }
    },
    {
        id = 1480,
        type = "tokenizer",
        name = "Number in TOP clause",
        input = "TOP 100",
        expected = {
            {type = "keyword", text = "TOP", line = 1, col = 1},
            {type = "number", text = "100", line = 1, col = 5}
        }
    },
}
