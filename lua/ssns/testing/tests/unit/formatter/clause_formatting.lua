-- Test file: clause_formatting.lua
-- IDs: 8051-8100
-- Tests: Clause-level formatting - SELECT, FROM, WHERE, GROUP BY, ORDER BY, JOINs

return {
    -- SELECT clause formatting
    {
        id = 8051,
        type = "formatter",
        name = "SELECT with multiple columns",
        input = "SELECT id,name,email,created_at FROM users",
        expected = {
            -- SSMS style puts columns on separate lines with trailing comma
            contains = { "SELECT id,", "name,", "email,", "created_at", "FROM users" }
        }
    },
    {
        id = 8052,
        type = "formatter",
        name = "SELECT with alias (AS keyword)",
        input = "SELECT id AS user_id, name AS user_name FROM users",
        expected = {
            contains = { "id AS user_id", "name AS user_name" }
        }
    },
    {
        id = 8053,
        type = "formatter",
        name = "SELECT DISTINCT",
        input = "select distinct name from users",
        expected = {
            contains = { "SELECT DISTINCT name" }
        }
    },
    {
        id = 8054,
        type = "formatter",
        name = "SELECT TOP (SQL Server)",
        input = "select top 10 * from users",
        expected = {
            contains = { "SELECT TOP 10 *" }
        }
    },
    {
        id = 8055,
        type = "formatter",
        name = "SELECT with aggregate functions",
        input = "SELECT COUNT(*), SUM(amount), AVG(price) FROM orders",
        expected = {
            contains = { "COUNT(*)", "SUM(amount)", "AVG(price)" }
        }
    },
    {
        id = 8056,
        type = "formatter",
        name = "SELECT with expression alias",
        input = "SELECT COUNT(*) AS cnt FROM users",
        expected = {
            contains = { "COUNT(*) AS cnt" }
        }
    },

    -- FROM clause formatting
    {
        id = 8060,
        type = "formatter",
        name = "FROM with table alias",
        input = "SELECT u.id FROM users u",
        expected = {
            contains = { "FROM users u" }
        }
    },
    {
        id = 8061,
        type = "formatter",
        name = "FROM with AS alias",
        input = "SELECT u.id FROM users AS u",
        expected = {
            contains = { "FROM users AS u" }
        }
    },

    -- JOIN formatting
    {
        id = 8065,
        type = "formatter",
        name = "INNER JOIN on new line",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id",
        expected = {
            formatted = "SELECT *\nFROM users u\nINNER JOIN orders o\n    ON u.id = o.user_id"
        }
    },
    {
        id = 8066,
        type = "formatter",
        name = "LEFT JOIN on new line",
        input = "SELECT * FROM users u LEFT JOIN orders o ON u.id = o.user_id",
        expected = {
            formatted = "SELECT *\nFROM users u\nLEFT JOIN orders o\n    ON u.id = o.user_id"
        }
    },
    {
        id = 8067,
        type = "formatter",
        name = "RIGHT JOIN on new line",
        input = "SELECT * FROM users u RIGHT JOIN orders o ON u.id = o.user_id",
        expected = {
            formatted = "SELECT *\nFROM users u\nRIGHT JOIN orders o\n    ON u.id = o.user_id"
        }
    },
    {
        id = 8068,
        type = "formatter",
        name = "LEFT OUTER JOIN",
        input = "SELECT * FROM users u LEFT OUTER JOIN orders o ON u.id = o.user_id",
        expected = {
            contains = { "LEFT OUTER JOIN orders o" }
        }
    },
    {
        id = 8069,
        type = "formatter",
        name = "CROSS JOIN",
        input = "SELECT * FROM users CROSS JOIN roles",
        expected = {
            contains = { "CROSS JOIN roles" }
        }
    },
    {
        id = 8070,
        type = "formatter",
        name = "Multiple JOINs",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id LEFT JOIN products p ON o.product_id = p.id",
        expected = {
            contains = { "INNER JOIN orders o", "LEFT JOIN products p" },
            matches = { "INNER JOIN.-ON.-LEFT JOIN" }
        }
    },

    -- WHERE clause formatting
    {
        id = 8075,
        type = "formatter",
        name = "WHERE with AND (leading position)",
        input = "SELECT * FROM users WHERE active = 1 AND verified = 1",
        expected = {
            formatted = "SELECT *\nFROM users\nWHERE active = 1\n    AND verified = 1"
        }
    },
    {
        id = 8076,
        type = "formatter",
        name = "WHERE with OR (leading position)",
        input = "SELECT * FROM users WHERE status = 'admin' OR status = 'moderator'",
        expected = {
            formatted = "SELECT *\nFROM users\nWHERE status = 'admin'\n    OR status = 'moderator'"
        }
    },
    {
        id = 8077,
        type = "formatter",
        name = "WHERE with multiple AND conditions",
        input = "SELECT * FROM users WHERE a = 1 AND b = 2 AND c = 3 AND d = 4",
        expected = {
            -- Note: first condition is on WHERE line, subsequent have AND
            contains = { "WHERE a = 1", "AND b = 2", "AND c = 3", "AND d = 4" }
        }
    },
    {
        id = 8078,
        type = "formatter",
        name = "WHERE IN clause",
        input = "SELECT * FROM users WHERE id IN (1, 2, 3)",
        expected = {
            contains = { "IN (1, 2, 3)" }
        }
    },
    {
        id = 8079,
        type = "formatter",
        name = "WHERE BETWEEN",
        input = "SELECT * FROM orders WHERE created_at BETWEEN '2024-01-01' AND '2024-12-31'",
        expected = {
            -- TODO: AND after BETWEEN should stay inline, but currently treated as clause separator
            contains = { "BETWEEN '2024-01-01'", "AND '2024-12-31'" }
        }
    },
    {
        id = 8080,
        type = "formatter",
        name = "WHERE LIKE",
        input = "SELECT * FROM users WHERE name LIKE 'John%'",
        expected = {
            contains = { "LIKE 'John%'" }
        }
    },
    {
        id = 8081,
        type = "formatter",
        name = "WHERE IS NULL",
        input = "SELECT * FROM users WHERE deleted_at IS NULL",
        expected = {
            contains = { "IS NULL" }
        }
    },
    {
        id = 8082,
        type = "formatter",
        name = "WHERE IS NOT NULL",
        input = "SELECT * FROM users WHERE email IS NOT NULL",
        expected = {
            contains = { "IS NOT NULL" }
        }
    },

    -- GROUP BY formatting
    {
        id = 8085,
        type = "formatter",
        name = "GROUP BY on new line",
        input = "SELECT department, COUNT(*) FROM employees GROUP BY department",
        expected = {
            -- SSMS style: columns on separate lines
            contains = { "SELECT department,", "COUNT(*)", "FROM employees", "GROUP BY department" }
        }
    },
    {
        id = 8086,
        type = "formatter",
        name = "GROUP BY multiple columns",
        input = "SELECT dept, category, COUNT(*) FROM employees GROUP BY dept, category",
        expected = {
            contains = { "GROUP BY dept, category" }
        }
    },
    {
        id = 8087,
        type = "formatter",
        name = "GROUP BY with HAVING",
        input = "SELECT dept, COUNT(*) AS cnt FROM employees GROUP BY dept HAVING COUNT(*) > 5",
        expected = {
            contains = { "GROUP BY dept", "HAVING COUNT(*) > 5" }
        }
    },

    -- ORDER BY formatting
    {
        id = 8090,
        type = "formatter",
        name = "ORDER BY on new line",
        input = "SELECT * FROM users ORDER BY name",
        expected = {
            formatted = "SELECT *\nFROM users\nORDER BY name"
        }
    },
    {
        id = 8091,
        type = "formatter",
        name = "ORDER BY ASC",
        input = "SELECT * FROM users ORDER BY name ASC",
        expected = {
            contains = { "ORDER BY name ASC" }
        }
    },
    {
        id = 8092,
        type = "formatter",
        name = "ORDER BY DESC",
        input = "SELECT * FROM users ORDER BY created_at DESC",
        expected = {
            contains = { "ORDER BY created_at DESC" }
        }
    },
    {
        id = 8093,
        type = "formatter",
        name = "ORDER BY multiple columns",
        input = "SELECT * FROM users ORDER BY last_name ASC, first_name ASC",
        expected = {
            contains = { "ORDER BY last_name ASC, first_name ASC" }
        }
    },
    {
        id = 8094,
        type = "formatter",
        name = "ORDER BY with NULLS FIRST (PostgreSQL)",
        input = "SELECT * FROM users ORDER BY name NULLS FIRST",
        expected = {
            contains = { "NULLS FIRST" }
        }
    },

    -- Set operations
    {
        id = 8095,
        type = "formatter",
        name = "UNION on new line",
        input = "SELECT id FROM users UNION SELECT id FROM admins",
        expected = {
            contains = { "UNION" },
            matches = { "\nUNION\n" }
        }
    },
    {
        id = 8096,
        type = "formatter",
        name = "UNION ALL",
        input = "SELECT id FROM users UNION ALL SELECT id FROM admins",
        expected = {
            contains = { "UNION ALL" }
        }
    },
    {
        id = 8097,
        type = "formatter",
        name = "INTERSECT",
        input = "SELECT id FROM users INTERSECT SELECT id FROM verified_users",
        expected = {
            contains = { "INTERSECT" }
        }
    },
    {
        id = 8098,
        type = "formatter",
        name = "EXCEPT",
        input = "SELECT id FROM all_users EXCEPT SELECT id FROM banned_users",
        expected = {
            contains = { "EXCEPT" }
        }
    },

    -- Complex query with all clauses
    {
        id = 8100,
        type = "formatter",
        name = "Full query with all clauses",
        input = "SELECT u.id, u.name, COUNT(o.id) AS order_count FROM users u INNER JOIN orders o ON u.id = o.user_id WHERE u.active = 1 AND o.status = 'completed' GROUP BY u.id, u.name HAVING COUNT(o.id) > 0 ORDER BY order_count DESC",
        expected = {
            -- SSMS style: columns on separate lines
            contains = {
                "SELECT u.id,",
                "u.name,",
                "COUNT(o.id) AS order_count",
                "FROM users u",
                "INNER JOIN orders o",
                "ON u.id = o.user_id",
                "WHERE u.active = 1",
                "AND o.status = 'completed'",
                "GROUP BY u.id, u.name",
                "HAVING COUNT(o.id) > 0",
                "ORDER BY order_count DESC"
            }
        }
    },
}
