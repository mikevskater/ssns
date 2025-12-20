-- Test file: casing_options.lua
-- IDs: 8351-8400
-- Tests: Casing config options - function_case, datatype_case, identifier_case, alias_case

return {
    -- function_case tests (default: upper)
    {
        id = 8351,
        type = "formatter",
        name = "function_case upper (default)",
        input = "SELECT count(*), sum(amount), avg(price) FROM orders",
        expected = {
            contains = { "COUNT(*)", "SUM(amount)", "AVG(price)" }
        }
    },
    {
        id = 8352,
        type = "formatter",
        name = "function_case lower",
        input = "SELECT COUNT(*), SUM(amount), AVG(price) FROM orders",
        opts = { function_case = "lower" },
        expected = {
            contains = { "count(*)", "sum(amount)", "avg(price)" },
            not_contains = { "COUNT", "SUM", "AVG" }
        }
    },
    {
        id = 8353,
        type = "formatter",
        name = "function_case preserve",
        input = "SELECT Count(*), SUM(amount), avg(price) FROM orders",
        opts = { function_case = "preserve" },
        expected = {
            contains = { "Count(*)", "SUM(amount)", "avg(price)" }
        }
    },
    {
        id = 8354,
        type = "formatter",
        name = "function_case with string functions",
        input = "SELECT upper(name), lower(email), len(description) FROM users",
        opts = { function_case = "upper" },
        expected = {
            contains = { "UPPER(name)", "LOWER(email)", "LEN(description)" }
        }
    },
    {
        id = 8355,
        type = "formatter",
        name = "function_case with date functions",
        input = "SELECT getdate(), dateadd(day, 1, created_at) FROM users",
        opts = { function_case = "upper" },
        expected = {
            -- Function names uppercased; dateparts like 'day' follow keyword_case (default: upper)
            contains = { "GETDATE()", "DATEADD(DAY, 1, created_at)" }
        }
    },

    -- datatype_case tests (default: upper)
    {
        id = 8360,
        type = "formatter",
        name = "datatype_case upper (default) in CAST",
        input = "SELECT cast(id AS int), cast(price AS decimal(10,2)) FROM products",
        expected = {
            contains = { "INT", "DECIMAL" }
        }
    },
    {
        id = 8361,
        type = "formatter",
        name = "datatype_case lower",
        input = "SELECT CAST(id AS INT), CAST(price AS DECIMAL(10,2)) FROM products",
        opts = { datatype_case = "lower" },
        expected = {
            contains = { "int", "decimal" },
            not_contains = { "INT", "DECIMAL" }
        }
    },
    {
        id = 8362,
        type = "formatter",
        name = "datatype_case preserve",
        input = "SELECT CAST(id AS Int), CAST(name AS Varchar(100)) FROM users",
        opts = { datatype_case = "preserve" },
        expected = {
            contains = { "Int", "Varchar" }
        }
    },
    {
        id = 8363,
        type = "formatter",
        name = "datatype_case with CONVERT",
        input = "SELECT convert(varchar(50), created_at, 120) FROM users",
        opts = { datatype_case = "upper" },
        expected = {
            contains = { "VARCHAR(50)" }
        }
    },

    -- identifier_case tests (default: preserve)
    {
        id = 8370,
        type = "formatter",
        name = "identifier_case preserve (default)",
        input = "SELECT UserName, EmailAddress FROM Users",
        expected = {
            contains = { "UserName", "EmailAddress", "Users" }
        }
    },
    {
        id = 8371,
        type = "formatter",
        name = "identifier_case lower",
        input = "SELECT UserName, EmailAddress FROM Users",
        opts = { identifier_case = "lower" },
        expected = {
            contains = { "username", "emailaddress", "users" },
            not_contains = { "UserName", "EmailAddress", "Users" }
        }
    },
    {
        id = 8372,
        type = "formatter",
        name = "identifier_case upper",
        input = "SELECT userName, emailAddress FROM users",
        opts = { identifier_case = "upper" },
        expected = {
            contains = { "USERNAME", "EMAILADDRESS", "USERS" }
        }
    },
    {
        id = 8373,
        type = "formatter",
        name = "identifier_case does not affect bracketed identifiers",
        input = "SELECT [UserName], [Email Address] FROM [User Table]",
        opts = { identifier_case = "lower" },
        expected = {
            -- Bracketed identifiers should be preserved as-is
            contains = { "[UserName]", "[Email Address]", "[User Table]" }
        }
    },

    -- alias_case tests (default: preserve)
    {
        id = 8380,
        type = "formatter",
        name = "alias_case preserve (default)",
        input = "SELECT u.Name AS UserName FROM users AS u",
        expected = {
            contains = { "AS UserName", "AS u" }
        }
    },

    -- Combined casing tests
    {
        id = 8390,
        type = "formatter",
        name = "All casing options together - mixed",
        input = "select count(*) as Total, cast(id as int) from users where upper(name) = 'TEST'",
        opts = {
            keyword_case = "upper",
            function_case = "lower",
            datatype_case = "lower"
        },
        expected = {
            contains = { "SELECT", "FROM", "WHERE" },  -- keywords upper
            -- functions and datatypes should be lower
        }
    },
    {
        id = 8391,
        type = "formatter",
        name = "keyword_case lower with function_case upper",
        input = "SELECT COUNT(*), SUM(amount) FROM orders WHERE id = 1",
        opts = {
            keyword_case = "lower",
            function_case = "upper"
        },
        expected = {
            contains = { "select", "from", "where" },  -- keywords lower
            not_contains = { "COUNT(*)", "SUM(amount)" }   -- functions upper
        }
    },
    {
        id = 8392,
        type = "formatter",
        name = "All lowercase",
        input = "SELECT COUNT(*) FROM USERS WHERE ID = 1",
        opts = {
            keyword_case = "lower",
            function_case = "lower",
            datatype_case = "lower",
            identifier_case = "lower"
        },
        expected = {
            contains = { "select", "count(*)", "from", "where" },
            not_contains = { "SELECT", "COUNT", "FROM", "WHERE" }
        }
    },
    {
        id = 8393,
        type = "formatter",
        name = "Keywords upper, rest preserve",
        input = "select Count(*) from Users where Id = 1",
        opts = {
            keyword_case = "upper",
            function_case = "preserve",
            identifier_case = "preserve"
        },
        expected = {
            contains = { "SELECT", "FROM", "WHERE" },  -- keywords uppercased
            not_contains = { "Count(*)", "Users", "Id" }   -- others preserved
        }
    },

    -- GO keyword casing
    {
        id = 8395,
        type = "formatter",
        name = "GO keyword follows keyword_case upper",
        input = "SELECT * FROM users\ngo",
        opts = { keyword_case = "upper" },
        expected = {
            contains = { "GO" },
            not_contains = { "go" }
        }
    },
    {
        id = 8396,
        type = "formatter",
        name = "GO keyword follows keyword_case lower",
        input = "SELECT * FROM users\nGO",
        opts = { keyword_case = "lower" },
        expected = {
            contains = { "go" },
            not_contains = { "GO" }
        }
    },

    -- Edge cases
    {
        id = 8398,
        type = "formatter",
        name = "Casing with nested functions",
        input = "select coalesce(nullif(name, ''), 'N/A') from users",
        opts = { function_case = "upper" },
        expected = {
            contains = { "COALESCE(NULLIF(name, ''), 'N/A')" }
        }
    },
    {
        id = 8399,
        type = "formatter",
        name = "Casing with window functions",
        input = "select row_number() over (partition by dept order by salary) from employees",
        opts = { function_case = "upper", keyword_case = "upper" },
        expected = {
            contains = { "ROW_NUMBER()", "OVER", "PARTITION BY", "ORDER BY" }
        }
    },
    {
        id = 8400,
        type = "formatter",
        name = "Casing preserves string literals",
        input = "SELECT * FROM users WHERE name = 'JOHN DOE'",
        opts = { keyword_case = "lower" },
        expected = {
            -- String literal should NOT be lowercased
            contains = { "'JOHN DOE'" }
        }
    },
}
