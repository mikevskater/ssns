-- Test file: advanced_formatting.lua
-- IDs: 8151-8200
-- Tests: Advanced SQL formatting - Subqueries, CTEs, CASE expressions, Window functions

return {
    -- Subquery formatting
    {
        id = 8151,
        type = "formatter",
        name = "Subquery in WHERE clause",
        input = "SELECT * FROM users WHERE id IN (SELECT user_id FROM orders)",
        expected = {
            contains = { "IN (", "SELECT user_id", "FROM orders" }
        }
    },
    {
        id = 8152,
        type = "formatter",
        name = "Subquery indentation",
        input = "SELECT * FROM users WHERE id IN (SELECT user_id FROM orders WHERE status='active')",
        expected = {
            matches = { "IN %(\n%s+SELECT" }
        }
    },
    {
        id = 8153,
        type = "formatter",
        name = "EXISTS subquery",
        input = "SELECT * FROM users u WHERE EXISTS (SELECT 1 FROM orders o WHERE o.user_id=u.id)",
        expected = {
            contains = { "EXISTS (", "SELECT 1", "FROM orders o" }
        }
    },
    {
        id = 8154,
        type = "formatter",
        name = "NOT EXISTS subquery",
        input = "SELECT * FROM users u WHERE NOT EXISTS (SELECT 1 FROM banned b WHERE b.user_id=u.id)",
        expected = {
            contains = { "NOT EXISTS (", "SELECT 1" }
        }
    },
    {
        id = 8155,
        type = "formatter",
        name = "Scalar subquery in SELECT",
        input = "SELECT name, (SELECT COUNT(*) FROM orders o WHERE o.user_id=u.id) AS order_count FROM users u",
        expected = {
            contains = { "(", "SELECT COUNT(*)", "FROM orders o" }
        }
    },
    {
        id = 8156,
        type = "formatter",
        name = "Subquery in FROM clause (derived table)",
        input = "SELECT * FROM (SELECT id, name FROM users WHERE active=1) AS active_users",
        expected = {
            contains = { "FROM (", "SELECT id, name", "FROM users", ") AS active_users" }
        }
    },
    {
        id = 8157,
        type = "formatter",
        name = "Nested subqueries",
        input = "SELECT * FROM users WHERE dept_id IN (SELECT id FROM depts WHERE company_id IN (SELECT id FROM companies WHERE active=1))",
        expected = {
            contains = { "dept_id IN (", "company_id IN (", "SELECT id FROM companies" }
        }
    },
    {
        id = 8158,
        type = "formatter",
        name = "Correlated subquery",
        input = "SELECT * FROM employees e WHERE salary > (SELECT AVG(salary) FROM employees WHERE department_id = e.department_id)",
        expected = {
            contains = { "salary > (", "SELECT AVG(salary)", "department_id = e.department_id" }
        }
    },

    -- CTE formatting
    {
        id = 8160,
        type = "formatter",
        name = "Simple CTE",
        input = "WITH active_users AS (SELECT * FROM users WHERE active=1) SELECT * FROM active_users",
        expected = {
            contains = { "WITH active_users AS (", "SELECT *", "FROM users", "FROM active_users" }
        }
    },
    {
        id = 8161,
        type = "formatter",
        name = "CTE body indentation",
        input = "WITH cte AS (SELECT id, name FROM users WHERE status='active') SELECT * FROM cte",
        expected = {
            matches = { "WITH cte AS %(\n%s+SELECT" }
        }
    },
    {
        id = 8162,
        type = "formatter",
        name = "Multiple CTEs",
        input = "WITH cte1 AS (SELECT * FROM t1), cte2 AS (SELECT * FROM t2) SELECT * FROM cte1 JOIN cte2 ON cte1.id=cte2.id",
        expected = {
            contains = { "WITH cte1 AS (", "cte2 AS (", "FROM cte1", "JOIN cte2" }
        }
    },
    {
        id = 8163,
        type = "formatter",
        name = "Recursive CTE",
        input = "WITH RECURSIVE tree AS (SELECT id, parent_id, name FROM nodes WHERE parent_id IS NULL UNION ALL SELECT n.id, n.parent_id, n.name FROM nodes n INNER JOIN tree t ON n.parent_id=t.id) SELECT * FROM tree",
        expected = {
            contains = { "WITH RECURSIVE tree AS (", "UNION ALL", "FROM tree" }
        }
    },
    {
        id = 8164,
        type = "formatter",
        name = "CTE with column list",
        input = "WITH numbered (row_num, id, name) AS (SELECT ROW_NUMBER() OVER (ORDER BY id), id, name FROM users) SELECT * FROM numbered",
        expected = {
            contains = { "numbered (row_num, id, name) AS (" }
        }
    },

    -- CASE expression formatting
    {
        id = 8170,
        type = "formatter",
        name = "Simple CASE expression",
        input = "SELECT CASE status WHEN 'A' THEN 'Active' WHEN 'I' THEN 'Inactive' ELSE 'Unknown' END FROM users",
        expected = {
            contains = { "CASE status", "WHEN 'A' THEN 'Active'", "WHEN 'I' THEN 'Inactive'", "ELSE 'Unknown'", "END" }
        }
    },
    {
        id = 8171,
        type = "formatter",
        name = "CASE WHEN newlines",
        input = "SELECT CASE WHEN a=1 THEN 'one' WHEN a=2 THEN 'two' ELSE 'other' END FROM t",
        expected = {
            matches = { "CASE\n%s+WHEN a = 1 THEN" }
        }
    },
    {
        id = 8172,
        type = "formatter",
        name = "Searched CASE expression",
        input = "SELECT CASE WHEN age < 18 THEN 'Minor' WHEN age < 65 THEN 'Adult' ELSE 'Senior' END AS age_group FROM users",
        expected = {
            contains = { "CASE", "WHEN age < 18 THEN 'Minor'", "WHEN age < 65 THEN 'Adult'", "ELSE 'Senior'", "END AS age_group" }
        }
    },
    {
        id = 8173,
        type = "formatter",
        name = "CASE with complex conditions",
        input = "SELECT CASE WHEN a > 0 AND b > 0 THEN 'positive' WHEN a < 0 OR b < 0 THEN 'negative' ELSE 'zero' END FROM t",
        expected = {
            contains = { "WHEN a > 0 AND b > 0", "WHEN a < 0 OR b < 0" }
        }
    },
    {
        id = 8174,
        type = "formatter",
        name = "Nested CASE expressions",
        input = "SELECT CASE WHEN type='A' THEN CASE WHEN sub='1' THEN 'A1' ELSE 'A2' END ELSE 'B' END FROM t",
        expected = {
            contains = { "CASE WHEN type = 'A'", "CASE WHEN sub = '1'", "END", "ELSE 'B'" }
        }
    },
    {
        id = 8175,
        type = "formatter",
        name = "CASE in ORDER BY",
        input = "SELECT * FROM users ORDER BY CASE WHEN priority='high' THEN 1 WHEN priority='medium' THEN 2 ELSE 3 END",
        expected = {
            contains = { "ORDER BY CASE", "WHEN priority = 'high'", "END" }
        }
    },
    {
        id = 8176,
        type = "formatter",
        name = "CASE in aggregate",
        input = "SELECT SUM(CASE WHEN status='completed' THEN amount ELSE 0 END) AS completed_total FROM orders",
        expected = {
            contains = { "SUM(CASE", "WHEN status = 'completed'", "END) AS completed_total" }
        }
    },

    -- Window function formatting
    {
        id = 8180,
        type = "formatter",
        name = "ROW_NUMBER window function",
        input = "SELECT ROW_NUMBER() OVER (ORDER BY id) AS rn, name FROM users",
        expected = {
            contains = { "ROW_NUMBER() OVER (ORDER BY id)", "AS rn" }
        }
    },
    {
        id = 8181,
        type = "formatter",
        name = "OVER with PARTITION BY",
        input = "SELECT dept, name, ROW_NUMBER() OVER (PARTITION BY dept ORDER BY name) AS rn FROM employees",
        expected = {
            contains = { "OVER (PARTITION BY dept ORDER BY name)" }
        }
    },
    {
        id = 8182,
        type = "formatter",
        name = "OVER clause stays inline",
        input = "SELECT id, SUM(amount) OVER (PARTITION BY category ORDER BY date) FROM sales",
        expected = {
            -- OVER clause should NOT have newlines inside
            not_contains = { "OVER (\n" }
        }
    },
    {
        id = 8183,
        type = "formatter",
        name = "RANK and DENSE_RANK",
        input = "SELECT name, RANK() OVER (ORDER BY score DESC) AS rank, DENSE_RANK() OVER (ORDER BY score DESC) AS dense_rank FROM students",
        expected = {
            contains = { "RANK() OVER", "DENSE_RANK() OVER" }
        }
    },
    {
        id = 8184,
        type = "formatter",
        name = "LAG and LEAD",
        input = "SELECT date, value, LAG(value,1) OVER (ORDER BY date) AS prev_value, LEAD(value,1) OVER (ORDER BY date) AS next_value FROM metrics",
        expected = {
            contains = { "LAG(value, 1) OVER", "LEAD(value, 1) OVER" }
        }
    },
    {
        id = 8185,
        type = "formatter",
        name = "Window frame clause",
        input = "SELECT date, SUM(amount) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_sum FROM sales",
        expected = {
            contains = { "ROWS BETWEEN 6 PRECEDING AND CURRENT ROW" }
        }
    },
    {
        id = 8186,
        type = "formatter",
        name = "Multiple window functions",
        input = "SELECT id, SUM(v) OVER (PARTITION BY g ORDER BY d), AVG(v) OVER (PARTITION BY g ORDER BY d), COUNT(*) OVER (PARTITION BY g) FROM t",
        expected = {
            contains = { "SUM(v) OVER (PARTITION BY", "AVG(v) OVER (PARTITION BY", "COUNT(*) OVER (PARTITION BY" }
        }
    },
    {
        id = 8187,
        type = "formatter",
        name = "Named window",
        input = "SELECT SUM(amount) OVER w FROM sales WINDOW w AS (PARTITION BY category ORDER BY date)",
        expected = {
            contains = { "OVER w", "WINDOW w AS" }
        }
    },

    -- Complex combinations
    {
        id = 8190,
        type = "formatter",
        name = "CTE with window function",
        input = "WITH ranked AS (SELECT *, ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC) AS rn FROM employees) SELECT * FROM ranked WHERE rn <= 3",
        expected = {
            contains = { "WITH ranked AS (", "ROW_NUMBER() OVER", "FROM ranked", "WHERE rn <= 3" }
        }
    },
    {
        id = 8191,
        type = "formatter",
        name = "Subquery with CASE",
        input = "SELECT * FROM users WHERE category = (SELECT CASE WHEN type='A' THEN 'cat1' ELSE 'cat2' END FROM config WHERE id=1)",
        expected = {
            contains = { "category = (", "SELECT CASE", "WHEN type = 'A'", "END" }
        }
    },
    {
        id = 8192,
        type = "formatter",
        name = "Window function in CASE",
        input = "SELECT CASE WHEN ROW_NUMBER() OVER (ORDER BY id)=1 THEN 'First' ELSE 'Other' END AS position FROM users",
        expected = {
            contains = { "CASE WHEN ROW_NUMBER() OVER", "THEN 'First'" }
        }
    },
    {
        id = 8193,
        type = "formatter",
        name = "CTE with subquery",
        input = "WITH filtered AS (SELECT * FROM users WHERE dept_id IN (SELECT id FROM depts WHERE active=1)) SELECT * FROM filtered",
        expected = {
            contains = { "WITH filtered AS (", "dept_id IN (", "SELECT id FROM depts", "FROM filtered" }
        }
    },

    -- Expression formatting
    {
        id = 8195,
        type = "formatter",
        name = "CAST expression",
        input = "SELECT CAST(id AS VARCHAR(10)), CAST(amount AS DECIMAL(10,2)) FROM t",
        expected = {
            contains = { "CAST(id AS VARCHAR(10))", "CAST(amount AS DECIMAL(10, 2))" }
        }
    },
    {
        id = 8196,
        type = "formatter",
        name = "CONVERT expression (SQL Server)",
        input = "SELECT CONVERT(VARCHAR(10),date,120), CONVERT(DECIMAL(10,2),amount) FROM t",
        expected = {
            contains = { "CONVERT(VARCHAR(10), date, 120)", "CONVERT(DECIMAL(10, 2), amount)" }
        }
    },
    {
        id = 8197,
        type = "formatter",
        name = "COALESCE and ISNULL",
        input = "SELECT COALESCE(a,b,c), ISNULL(x,'default') FROM t",
        expected = {
            contains = { "COALESCE(a, b, c)", "ISNULL(x, 'default')" }
        }
    },
    {
        id = 8198,
        type = "formatter",
        name = "Arithmetic expressions",
        input = "SELECT price*quantity AS total, (price+tax)*quantity AS grand_total FROM orders",
        expected = {
            contains = { "price * quantity", "(price + tax) * quantity" }
        }
    },
    {
        id = 8199,
        type = "formatter",
        name = "String concatenation",
        input = "SELECT first_name+' '+last_name AS full_name FROM users",
        expected = {
            contains = { "first_name + ' ' + last_name" }
        }
    },
    {
        id = 8200,
        type = "formatter",
        name = "Complex nested expression",
        input = "SELECT COALESCE(NULLIF(LTRIM(RTRIM(name)),''),default_name) AS clean_name FROM users",
        expected = {
            contains = { "COALESCE(NULLIF(LTRIM(RTRIM(name)), ''), default_name)" }
        }
    },
}
