-- Test file: spacing_options.lua
-- IDs: 8401-8450
-- Tests: Spacing config options - comma_spacing, semicolon_spacing, bracket_spacing, operator spacing

return {
    -- comma_spacing tests (default: "after")
    -- Note: SELECT columns go on separate lines with trailing commas, so test in function calls
    {
        id = 8401,
        type = "formatter",
        name = "comma_spacing after (default)",
        input = "SELECT COALESCE(a,b,c) FROM users",
        expected = {
            contains = { "COALESCE(a, b, c)" }  -- Space after comma in function args
        }
    },
    {
        id = 8402,
        type = "formatter",
        name = "comma_spacing before",
        input = "SELECT COALESCE(a, b, c) FROM users",
        opts = { comma_spacing = "before" },
        expected = {
            contains = { "COALESCE(a ,b ,c)" }
        }
    },
    {
        id = 8403,
        type = "formatter",
        name = "comma_spacing both",
        input = "SELECT COALESCE(a,b,c) FROM users",
        opts = { comma_spacing = "both" },
        expected = {
            contains = { "COALESCE(a , b , c)" }
        }
    },
    {
        id = 8404,
        type = "formatter",
        name = "comma_spacing none",
        input = "SELECT COALESCE(a, b, c) FROM users",
        opts = { comma_spacing = "none" },
        expected = {
            contains = { "COALESCE(a,b,c)" }
        }
    },
    {
        id = 8405,
        type = "formatter",
        name = "comma_spacing in nested function args",
        input = "SELECT ISNULL(NULLIF(a,''),b) FROM users",
        opts = { comma_spacing = "after" },
        expected = {
            contains = { "ISNULL(NULLIF(a, ''), b)" }
        }
    },

    -- semicolon_spacing tests (default: false - no space before)
    {
        id = 8410,
        type = "formatter",
        name = "semicolon_spacing false (default)",
        input = "SELECT * FROM users ;",
        expected = {
            contains = { "users;" },
            not_contains = { "users ;" }
        }
    },
    {
        id = 8411,
        type = "formatter",
        name = "semicolon_spacing true",
        input = "SELECT * FROM users;",
        opts = { semicolon_spacing = true },
        expected = {
            contains = { "users ;" }
        }
    },

    -- parenthesis_spacing tests (default: false)
    {
        id = 8415,
        type = "formatter",
        name = "parenthesis_spacing false (default)",
        input = "SELECT COUNT( * ) FROM users",
        expected = {
            contains = { "COUNT(*)" }
        }
    },
    {
        id = 8416,
        type = "formatter",
        name = "parenthesis_spacing true",
        input = "SELECT COUNT(*) FROM users",
        opts = { parenthesis_spacing = true },
        expected = {
            contains = { "COUNT( * )" }
        }
    },
    {
        id = 8417,
        type = "formatter",
        name = "parenthesis_spacing with multiple args",
        input = "SELECT COALESCE(a,b,c) FROM users",
        opts = { parenthesis_spacing = true },
        expected = {
            contains = { "( a, b, c )" }
        }
    },

    -- equals_spacing tests (default: true)
    {
        id = 8420,
        type = "formatter",
        name = "equals_spacing true (default)",
        input = "SELECT * FROM users WHERE id=1",
        expected = {
            contains = { "id = 1" }
        }
    },
    {
        id = 8421,
        type = "formatter",
        name = "equals_spacing false",
        input = "SELECT * FROM users WHERE id = 1",
        opts = { equals_spacing = false },
        expected = {
            contains = { "id=1" }
        }
    },
    {
        id = 8422,
        type = "formatter",
        name = "equals_spacing in SET clause",
        input = "UPDATE users SET name='John' WHERE id=1",
        opts = { equals_spacing = true },
        expected = {
            contains = { "name = 'John'", "id = 1" }
        }
    },

    -- comparison_spacing tests (default: true)
    {
        id = 8425,
        type = "formatter",
        name = "comparison_spacing true (default) - greater than",
        input = "SELECT * FROM users WHERE age>18",
        expected = {
            contains = { "age > 18" }
        }
    },
    {
        id = 8426,
        type = "formatter",
        name = "comparison_spacing true - less than",
        input = "SELECT * FROM users WHERE age<65",
        expected = {
            contains = { "age < 65" }
        }
    },
    {
        id = 8427,
        type = "formatter",
        name = "comparison_spacing true - not equal",
        input = "SELECT * FROM users WHERE status<>'deleted'",
        expected = {
            contains = { "status <> 'deleted'" }
        }
    },
    {
        id = 8428,
        type = "formatter",
        name = "comparison_spacing true - greater or equal",
        input = "SELECT * FROM users WHERE age>=21",
        expected = {
            contains = { "age >= 21" }
        }
    },
    {
        id = 8429,
        type = "formatter",
        name = "comparison_spacing false",
        input = "SELECT * FROM users WHERE age > 18",
        opts = { comparison_spacing = false },
        expected = {
            contains = { "age>18" }
        }
    },

    -- operator_spacing tests (default: true - for arithmetic)
    {
        id = 8430,
        type = "formatter",
        name = "operator_spacing true (default) - addition",
        input = "SELECT price+tax FROM products",
        expected = {
            contains = { "price + tax" }
        }
    },
    {
        id = 8431,
        type = "formatter",
        name = "operator_spacing true - subtraction",
        input = "SELECT gross-deductions FROM payroll",
        expected = {
            contains = { "gross - deductions" }
        }
    },
    {
        id = 8432,
        type = "formatter",
        name = "operator_spacing true - multiplication",
        input = "SELECT quantity*price FROM orders",
        expected = {
            contains = { "quantity * price" }
        }
    },
    {
        id = 8433,
        type = "formatter",
        name = "operator_spacing true - division",
        input = "SELECT total/[count] FROM stats",  -- Bracket identifier treated as object
        expected = {
            contains = { "total / [count]" }
        }
    },
    {
        id = 8434,
        type = "formatter",
        name = "operator_spacing false",
        input = "SELECT price + tax FROM products",
        opts = { operator_spacing = false },
        expected = {
            contains = { "price+tax" }
        }
    },

    -- concatenation_spacing tests (default: true)
    {
        id = 8440,
        type = "formatter",
        name = "concatenation_spacing true (default) - plus operator",
        input = "SELECT first_name+' '+last_name FROM users",
        expected = {
            contains = { "first_name + ' ' + last_name" }
        }
    },
    {
        id = 8441,
        type = "formatter",
        name = "concatenation_spacing false (uses operator_spacing for +)",
        input = "SELECT first_name + ' ' + last_name FROM users",
        opts = { operator_spacing = false },  -- + is handled by operator_spacing
        expected = {
            contains = { "first_name+' '+last_name" }
        }
    },

    -- PostgreSQL :: cast operator (always no space)
    {
        id = 8445,
        type = "formatter",
        name = "No space around PostgreSQL :: cast operator",
        input = "SELECT id :: int FROM users",
        expected = {
            contains = { "id::INT" }  -- Datatype is uppercased by default
        }
    },

    -- Combined spacing tests
    {
        id = 8448,
        type = "formatter",
        name = "All spacing options combined",
        input = "SELECT CONCAT(a,b,c) FROM t WHERE x=1 AND y>2;",
        opts = {
            comma_spacing = "after",
            equals_spacing = true,
            comparison_spacing = true
        },
        expected = {
            contains = { "CONCAT(a, b, c)", "x = 1", "y > 2" }
        }
    },
    {
        id = 8449,
        type = "formatter",
        name = "Compact spacing style",
        input = "SELECT CONCAT(a, b, c) FROM t WHERE x = 1 AND y > 2;",
        opts = {
            comma_spacing = "none",
            equals_spacing = false,
            comparison_spacing = false,
            operator_spacing = false
        },
        expected = {
            contains = { "CONCAT(a,b,c)", "x=1", "y>2" }
        }
    },
    {
        id = 8450,
        type = "formatter",
        name = "Loose spacing style",
        input = "SELECT CONCAT(a,b) FROM t WHERE x=1",
        opts = {
            comma_spacing = "both",
            parenthesis_spacing = true,
            equals_spacing = true
        },
        expected = {
            contains = { "CONCAT( a , b )", "x = 1" }
        }
    },
}
