-- Test file: from_options.lua
-- IDs: 8466-8469, 8530-8535, 8596-85996, 8770-8779, 8780-8795
-- Tests: FROM clause options - from_newline, alias_align, table_style, hints, schema_qualify

return {
    -- FROM clause newline options
    {
        id = 8466,
        type = "formatter",
        name = "from_newline true (default) - FROM on new line",
        input = "SELECT id, name FROM users",
        opts = { from_newline = true },
        expected = {
            matches = { "SELECT.-\nFROM" }
        }
    },
    {
        id = 8467,
        type = "formatter",
        name = "from_newline false - FROM on same line",
        input = "SELECT id, name FROM users",
        opts = { from_newline = false },
        expected = {
            contains = { "name FROM users" }
        }
    },
    {
        id = 8468,
        type = "formatter",
        name = "from_newline false with multiple columns",
        input = "SELECT a, b, c FROM t",
        opts = { from_newline = false, select_list_style = "inline" },
        expected = {
            -- Everything on one line when both options set
            contains = { "SELECT a, b, c FROM t" }
        }
    },
    {
        id = 8469,
        type = "formatter",
        name = "from_newline false still keeps WHERE on new line",
        input = "SELECT * FROM users WHERE active = 1",
        opts = { from_newline = false },
        expected = {
            -- FROM on same line as SELECT, but WHERE on new line
            contains = { "SELECT * FROM users" },
            matches = { "\nWHERE" }
        }
    },

    -- from_alias_align tests
    {
        id = 8530,
        type = "formatter",
        name = "from_alias_align true - basic alignment",
        input = "SELECT * FROM users u JOIN orders o ON u.id = o.user_id",
        opts = { from_alias_align = true },
        expected = {
            -- users (5 chars) and orders (6 chars) - users gets 1 space padding
            contains = { "users  u", "orders o" }
        }
    },
    {
        id = 8531,
        type = "formatter",
        name = "from_alias_align true - multiple joins",
        input = "SELECT * FROM users u JOIN orders o ON u.id = o.user_id JOIN order_items oi ON o.id = oi.order_id",
        opts = { from_alias_align = true },
        expected = {
            -- users (5), orders (6), order_items (11) - align to 11
            contains = { "users       u", "orders      o", "order_items oi" }
        }
    },
    {
        id = 8532,
        type = "formatter",
        name = "from_alias_align false - no alignment",
        input = "SELECT * FROM users u JOIN orders o ON u.id = o.user_id",
        opts = { from_alias_align = false },
        expected = {
            -- Standard spacing
            contains = { "users u", "orders o" }
        }
    },
    {
        id = 8533,
        type = "formatter",
        name = "from_alias_align with schema-qualified tables",
        input = "SELECT * FROM dbo.users u JOIN dbo.orders o ON u.id = o.user_id",
        opts = { from_alias_align = true },
        expected = {
            -- dbo.users (9 chars) and dbo.orders (10 chars)
            contains = { "dbo.users  u", "dbo.orders o" }
        }
    },
    {
        id = 8534,
        type = "formatter",
        name = "from_alias_align with AS keyword",
        input = "SELECT * FROM users AS u JOIN orders AS o ON u.id = o.user_id",
        opts = { from_alias_align = true },
        expected = {
            -- AS keyword should be included in alignment
            contains = { "users  AS u", "orders AS o" }
        }
    },
    {
        id = 8535,
        type = "formatter",
        name = "from_alias_align with LEFT/RIGHT joins",
        input = "SELECT * FROM users u LEFT JOIN orders o ON u.id = o.user_id RIGHT JOIN payments p ON o.id = p.order_id",
        opts = { from_alias_align = true },
        expected = {
            -- users (5), orders (6), payments (8)
            contains = { "users    u", "orders   o", "payments p" }
        }
    },

    -- from_table_style tests
    {
        id = 8596,
        type = "formatter",
        name = "from_table_style inline (default) - multiple tables on one line",
        input = "SELECT * FROM users, orders, products",
        opts = { from_table_style = "inline" },
        expected = {
            contains = { "FROM users, orders, products" }
        }
    },
    {
        id = 8597,
        type = "formatter",
        name = "from_table_style stacked - each table on new line",
        input = "SELECT * FROM users, orders, products",
        opts = { from_table_style = "stacked" },
        expected = {
            matches = { "FROM users,\n%s*orders,\n%s*products" }
        }
    },
    {
        id = 8598,
        type = "formatter",
        name = "from_table_style stacked_indent - first table on new line",
        input = "SELECT * FROM users, orders, products",
        opts = { from_table_style = "stacked_indent" },
        expected = {
            -- First table should be on new line after FROM
            matches = { "FROM\n%s+users,\n%s+orders,\n%s+products" }
        }
    },
    {
        id = 8599,
        type = "formatter",
        name = "from_table_style stacked vs stacked_indent comparison",
        input = "SELECT * FROM a, b FROM t",
        opts = { from_table_style = "stacked" },
        expected = {
            -- stacked: first table on same line as FROM
            contains = { "FROM a," }
        }
    },
    {
        id = 85991,
        type = "formatter",
        name = "from_table_style stacked with aliases",
        input = "SELECT * FROM users u, orders o, products p",
        opts = { from_table_style = "stacked" },
        expected = {
            matches = { "FROM users u,\n%s*orders o,\n%s*products p" }
        }
    },
    {
        id = 85992,
        type = "formatter",
        name = "from_table_style stacked_indent with aliases",
        input = "SELECT * FROM users u, orders o",
        opts = { from_table_style = "stacked_indent" },
        expected = {
            matches = { "FROM\n%s+users u,\n%s+orders o" }
        }
    },
    {
        id = 85993,
        type = "formatter",
        name = "from_table_style inline preserves single table",
        input = "SELECT * FROM users WHERE id = 1",
        opts = { from_table_style = "inline" },
        expected = {
            contains = { "FROM users" }
        }
    },
    {
        id = 85994,
        type = "formatter",
        name = "from_table_style stacked with schema-qualified tables",
        input = "SELECT * FROM dbo.users, dbo.orders",
        opts = { from_table_style = "stacked" },
        expected = {
            matches = { "FROM dbo.users,\n%s*dbo.orders" }
        }
    },
    {
        id = 85995,
        type = "formatter",
        name = "from_table_style inline - doesn't affect JOINs",
        input = "SELECT * FROM users, orders JOIN products ON orders.product_id = products.id",
        opts = { from_table_style = "inline" },
        expected = {
            -- JOIN should still be on new line (controlled by join_newline)
            contains = { "FROM users, orders" },
            matches = { "\nJOIN products" }
        }
    },
    {
        id = 85996,
        type = "formatter",
        name = "from_table_style stacked - subquery tables not affected",
        input = "SELECT * FROM (SELECT id FROM users) AS sub, orders",
        opts = { from_table_style = "stacked" },
        expected = {
            -- Subquery content handled separately, outer tables stacked
            contains = { "AS sub," }
        }
    },

    -- from_table_hints_newline tests
    {
        id = 8770,
        type = "formatter",
        name = "from_table_hints_newline true - basic NOLOCK",
        input = "SELECT * FROM users WITH (NOLOCK) WHERE id = 1",
        opts = { from_table_hints_newline = true },
        expected = {
            -- WITH should be on new line when from_table_hints_newline = true
            matches = { "users\n.-WITH %(" }
        }
    },
    {
        id = 8771,
        type = "formatter",
        name = "from_table_hints_newline false - NOLOCK stays inline",
        input = "SELECT * FROM users WITH (NOLOCK) WHERE id = 1",
        opts = { from_table_hints_newline = false },
        expected = {
            -- WITH stays on same line as table
            contains = { "users WITH (NOLOCK)" }
        }
    },
    {
        id = 8772,
        type = "formatter",
        name = "from_table_hints_newline true - table with alias",
        input = "SELECT * FROM users u WITH (NOLOCK) WHERE u.id = 1",
        opts = { from_table_hints_newline = true },
        expected = {
            -- WITH should be on new line after alias
            matches = { "users u\n.-WITH %(" }
        }
    },
    {
        id = 8773,
        type = "formatter",
        name = "from_table_hints_newline true - JOIN table hint",
        input = "SELECT * FROM users u JOIN orders o WITH (NOLOCK) ON u.id = o.user_id",
        opts = { from_table_hints_newline = true },
        expected = {
            -- WITH should be on new line after JOIN table alias
            matches = { "orders o\n.-WITH %(" }
        }
    },
    {
        id = 8774,
        type = "formatter",
        name = "from_table_hints_newline true - multiple hints",
        input = "SELECT * FROM users WITH (NOLOCK, ROWLOCK) WHERE id = 1",
        opts = { from_table_hints_newline = true },
        expected = {
            -- WITH should be on new line, hints stay together
            matches = { "users\n.-WITH %(NOLOCK, ROWLOCK%)" }
        }
    },
    {
        id = 8775,
        type = "formatter",
        name = "from_table_hints_newline true - schema qualified table",
        input = "SELECT * FROM dbo.users WITH (NOLOCK) WHERE id = 1",
        opts = { from_table_hints_newline = true },
        expected = {
            matches = { "dbo.users\n.-WITH %(" }
        }
    },
    {
        id = 8776,
        type = "formatter",
        name = "from_table_hints_newline - doesn't affect CTE WITH",
        input = "WITH cte AS (SELECT 1) SELECT * FROM cte",
        opts = { from_table_hints_newline = true },
        expected = {
            -- CTE WITH should NOT get newline treatment
            contains = { "WITH cte AS" }
        }
    },
    {
        id = 8777,
        type = "formatter",
        name = "from_table_hints_newline true - UPDLOCK hint",
        input = "SELECT * FROM users WITH (UPDLOCK) WHERE id = 1",
        opts = { from_table_hints_newline = true },
        expected = {
            matches = { "users\n.-WITH %(UPDLOCK%)" }
        }
    },
    {
        id = 8778,
        type = "formatter",
        name = "from_table_hints_newline true - multiple tables with hints",
        input = "SELECT * FROM users u WITH (NOLOCK), orders o WITH (NOLOCK) WHERE u.id = o.user_id",
        opts = { from_table_hints_newline = true, from_table_style = "stacked" },
        expected = {
            -- Both tables should have WITH on new line
            matches = { "u\n.-WITH", "o\n.-WITH" }
        }
    },
    {
        id = 8779,
        type = "formatter",
        name = "from_table_hints_newline true - proper indentation",
        input = "SELECT * FROM users WITH (NOLOCK) WHERE id = 1",
        opts = { from_table_hints_newline = true },
        expected = {
            -- WITH should be indented (4 spaces by default)
            matches = { "users\n    WITH" }
        }
    },

    -- from_schema_qualify tests
    -- Options: "preserve" (default), "always" (lookup from cache), "never" (remove schema prefix)
    -- NOTE: "always" mode requires database connection to look up actual schemas.
    --       Without connection, tables that already have schema are preserved,
    --       and unqualified tables remain unqualified (lookup fails gracefully).
    --       These tests cover the "preserve" and "never" modes which work without connection.

    -- PRESERVE mode tests (default - no changes)
    {
        id = 8780,
        type = "formatter",
        name = "from_schema_qualify preserve (default) - unqualified table unchanged",
        input = "SELECT * FROM users WHERE id = 1",
        opts = { from_schema_qualify = "preserve" },
        expected = {
            -- Table name stays as-is
            contains = { "FROM users" }
        }
    },
    {
        id = 8781,
        type = "formatter",
        name = "from_schema_qualify preserve - keeps existing dbo schema",
        input = "SELECT * FROM dbo.users WHERE id = 1",
        opts = { from_schema_qualify = "preserve" },
        expected = {
            -- Schema-qualified name stays as-is
            contains = { "FROM dbo.users" }
        }
    },
    {
        id = 8782,
        type = "formatter",
        name = "from_schema_qualify preserve - keeps existing non-dbo schema",
        input = "SELECT * FROM sales.orders WHERE id = 1",
        opts = { from_schema_qualify = "preserve" },
        expected = {
            -- Non-dbo schema preserved
            contains = { "FROM sales.orders" }
        }
    },
    {
        id = 8783,
        type = "formatter",
        name = "from_schema_qualify preserve - keeps three-part names",
        input = "SELECT * FROM mydb.dbo.users WHERE id = 1",
        opts = { from_schema_qualify = "preserve" },
        expected = {
            -- Three-part name stays as-is
            contains = { "FROM mydb.dbo.users" }
        }
    },

    -- NEVER mode tests (remove schema prefixes)
    {
        id = 8784,
        type = "formatter",
        name = "from_schema_qualify never - removes dbo schema",
        input = "SELECT * FROM dbo.users WHERE id = 1",
        opts = { from_schema_qualify = "never" },
        expected = {
            -- dbo. prefix removed
            contains = { "FROM users" }
        }
    },
    {
        id = 8785,
        type = "formatter",
        name = "from_schema_qualify never - removes non-dbo schema",
        input = "SELECT * FROM sales.orders WHERE id = 1",
        opts = { from_schema_qualify = "never" },
        expected = {
            -- Schema prefix removed
            contains = { "FROM orders" }
        }
    },
    {
        id = 8786,
        type = "formatter",
        name = "from_schema_qualify never - removes schema from three-part name",
        input = "SELECT * FROM mydb.dbo.users WHERE id = 1",
        opts = { from_schema_qualify = "never" },
        expected = {
            -- Both database and schema removed, just table name
            contains = { "FROM users" }
        }
    },
    {
        id = 8787,
        type = "formatter",
        name = "from_schema_qualify never - multiple tables",
        input = "SELECT * FROM dbo.users, sales.orders, hr.employees",
        opts = { from_schema_qualify = "never" },
        expected = {
            -- All schema prefixes removed
            contains = { "users", "orders", "employees" },
            excludes = { "dbo.users", "sales.orders", "hr.employees" }
        }
    },
    {
        id = 8788,
        type = "formatter",
        name = "from_schema_qualify never - JOIN tables",
        input = "SELECT * FROM dbo.users u JOIN dbo.orders o ON u.id = o.user_id",
        opts = { from_schema_qualify = "never" },
        expected = {
            -- Both tables have schema removed
            contains = { "FROM users", "JOIN orders" }
        }
    },
    {
        id = 8789,
        type = "formatter",
        name = "from_schema_qualify never - INSERT table",
        input = "INSERT INTO dbo.users (id, name) VALUES (1, 'John')",
        opts = { from_schema_qualify = "never" },
        expected = {
            -- INSERT table has schema removed
            contains = { "INSERT INTO users" }
        }
    },
    {
        id = 8790,
        type = "formatter",
        name = "from_schema_qualify never - UPDATE table",
        input = "UPDATE dbo.users SET name = 'Jane' WHERE id = 1",
        opts = { from_schema_qualify = "never" },
        expected = {
            -- UPDATE table has schema removed
            contains = { "UPDATE users" }
        }
    },
    {
        id = 8791,
        type = "formatter",
        name = "from_schema_qualify never - DELETE table",
        input = "DELETE FROM dbo.users WHERE id = 1",
        opts = { from_schema_qualify = "never" },
        expected = {
            -- DELETE table has schema removed (formatter may add newline after DELETE)
            contains = { "FROM users" },
            excludes = { "dbo.users" }
        }
    },
    {
        id = 8792,
        type = "formatter",
        name = "from_schema_qualify never - preserves table alias",
        input = "SELECT * FROM dbo.users u WHERE u.id = 1",
        opts = { from_schema_qualify = "never" },
        expected = {
            -- Schema removed, alias preserved
            contains = { "FROM users u" }
        }
    },
    {
        id = 8793,
        type = "formatter",
        name = "from_schema_qualify never - doesn't affect column references",
        input = "SELECT u.id, u.name FROM dbo.users u",
        opts = { from_schema_qualify = "never" },
        expected = {
            -- Only table schema removed, column references unchanged
            contains = { "FROM users u", "u.id", "u.name" }
        }
    },
    {
        id = 8794,
        type = "formatter",
        name = "from_schema_qualify never - unqualified tables unchanged",
        input = "SELECT * FROM users WHERE id = 1",
        opts = { from_schema_qualify = "never" },
        expected = {
            -- Unqualified table stays unqualified
            contains = { "FROM users" }
        }
    },
    {
        id = 8795,
        type = "formatter",
        name = "from_schema_qualify never - mixed qualified and unqualified",
        input = "SELECT * FROM dbo.users u JOIN orders o ON u.id = o.user_id",
        opts = { from_schema_qualify = "never" },
        expected = {
            -- Qualified becomes unqualified, unqualified stays unqualified
            contains = { "FROM users u", "JOIN orders o" }
        }
    },
}
