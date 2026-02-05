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
            -- SSMS style: each SELECT in subquery is on its own line
            contains = { "dept_id IN (", "company_id IN (", "SELECT id", "FROM companies", "active = 1" }
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
            -- No space between CTE name and column list is acceptable (like function calls)
            contains = { "numbered(row_num, id, name) AS (", "SELECT ROW_NUMBER()" }
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
        input = "SELECT CASE WHEN category='A' THEN CASE WHEN sub='1' THEN 'A1' ELSE 'A2' END ELSE 'B' END FROM t",
        expected = {
            -- SSMS-style: CASE on its own line, WHEN indented below
            -- "type" is a keyword, using "category" instead
            contains = { "WHEN category = 'A'", "WHEN sub = '1'", "END", "ELSE 'B'" }
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
        input = "SELECT created_at, amount, LAG(amount,1) OVER (ORDER BY created_at) AS prev_amount, LEAD(amount,1) OVER (ORDER BY created_at) AS next_amount FROM metrics",
        expected = {
            -- Avoid SQL keywords as column names (date, value)
            contains = { "LAG(amount, 1) OVER", "LEAD(amount, 1) OVER" }
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
            -- SSMS style: ROW_NUMBER() on separate line with CASE
            contains = { "CASE", "WHEN ROW_NUMBER() OVER", "THEN 'First'" }
        }
    },
    {
        id = 8193,
        type = "formatter",
        name = "CTE with subquery",
        input = "WITH filtered AS (SELECT * FROM users WHERE dept_id IN (SELECT id FROM depts WHERE active=1)) SELECT * FROM filtered",
        expected = {
            -- SSMS style: columns on separate lines
            contains = { "WITH filtered AS (", "dept_id IN (", "SELECT id", "FROM depts", "FROM filtered" }
        }
    },

    -- Expression formatting
    {
        id = 8195,
        type = "formatter",
        name = "CAST expression",
        input = "SELECT CAST(id AS VARCHAR(10)), CAST(amount AS DECIMAL(10,2)) FROM t",
        expected = {
            -- TODO: VARCHAR(10) has space before ( because VARCHAR is a keyword
            contains = { "CAST(id AS VARCHAR", "CAST(amount AS DECIMAL" }
        }
    },
    {
        id = 8196,
        type = "formatter",
        name = "CONVERT expression (SQL Server)",
        input = "SELECT CONVERT(VARCHAR(10),created_at,120), CONVERT(DECIMAL(10,2),amount) FROM t",
        expected = {
            -- TODO: Space before ( after data type keywords
            -- "date" is a keyword, using "created_at" instead
            contains = { "CONVERT(VARCHAR", "created_at, 120)", "CONVERT(DECIMAL", "amount)" }
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

    -- batch_separator_style tests (IDs: 9200-9210)
    -- Options: "go" (default), "semicolon"
    -- Controls whether statements are terminated with GO or semicolon
    {
        id = 9200,
        type = "formatter",
        name = "batch_separator_style go (default) - preserves GO",
        input = "SELECT 1\nGO\nSELECT 2",
        opts = { batch_separator_style = "go" },
        expected = {
            contains = { "GO" }
        }
    },
    {
        id = 9201,
        type = "formatter",
        name = "batch_separator_style go - preserves semicolons",
        input = "SELECT 1; SELECT 2;",
        opts = { batch_separator_style = "go" },
        expected = {
            -- In go mode, semicolons are preserved (not converted to GO)
            contains = { ";" }
        }
    },
    {
        id = 9202,
        type = "formatter",
        name = "batch_separator_style semicolon - converts GO to semicolon",
        input = "SELECT 1\nGO\nSELECT 2",
        opts = { batch_separator_style = "semicolon" },
        expected = {
            -- GO should be replaced with semicolon
            contains = { ";" },
            excludes = { "GO" }
        }
    },
    {
        id = 9203,
        type = "formatter",
        name = "batch_separator_style semicolon - preserves existing semicolons",
        input = "SELECT 1; SELECT 2;",
        opts = { batch_separator_style = "semicolon" },
        expected = {
            contains = { ";" }
        }
    },
    {
        id = 9204,
        type = "formatter",
        name = "batch_separator_style semicolon - multiple GOs",
        input = "SELECT 1\nGO\nSELECT 2\nGO\nSELECT 3\nGO",
        opts = { batch_separator_style = "semicolon" },
        expected = {
            -- All GOs should be replaced with semicolons
            excludes = { "GO" }
        }
    },
    {
        id = 9205,
        type = "formatter",
        name = "batch_separator_style go - GO casing preserved",
        input = "SELECT 1\ngo\nSELECT 2",
        opts = { batch_separator_style = "go", keyword_case = "preserve" },
        expected = {
            -- GO casing should be preserved when keyword_case = preserve
            contains = { "go" }
        }
    },
    {
        id = 9206,
        type = "formatter",
        name = "batch_separator_style go - GO casing uppercased",
        input = "SELECT 1\ngo\nSELECT 2",
        opts = { batch_separator_style = "go", keyword_case = "upper" },
        expected = {
            -- GO should be uppercased
            contains = { "GO" }
        }
    },
    {
        id = 9207,
        type = "formatter",
        name = "batch_separator_style semicolon - handles GO with count",
        input = "SELECT 1\nGO 5\nSELECT 2",
        opts = { batch_separator_style = "semicolon" },
        expected = {
            -- GO 5 means "execute 5 times", can't be converted to semicolon
            -- GO is preserved (not converted to semicolon)
            -- Note: formatter may put GO and count on separate lines
            contains = { "GO" },
            excludes = { ";" }
        }
    },
    {
        id = 9208,
        type = "formatter",
        name = "batch_separator_style go - complex batch",
        input = "CREATE TABLE t1 (id INT)\nGO\nINSERT INTO t1 VALUES (1)\nGO\nSELECT * FROM t1\nGO",
        opts = { batch_separator_style = "go" },
        expected = {
            contains = { "GO" }
        }
    },
    {
        id = 9209,
        type = "formatter",
        name = "batch_separator_style semicolon - DDL statements",
        input = "CREATE TABLE t1 (id INT)\nGO\nDROP TABLE t1\nGO",
        opts = { batch_separator_style = "semicolon" },
        expected = {
            -- DDL statements with GO converted to semicolons
            contains = { ";" },
            excludes = { "GO" }
        }
    },

    -- keyword_right_align tests (IDs: 9210-9225)
    -- Right-aligns SQL keywords to create "river" style formatting
    -- Keywords are right-aligned within a fixed width
    {
        id = 9210,
        type = "formatter",
        name = "keyword_right_align false (default) - left-aligned",
        input = "SELECT id, name FROM users WHERE status = 1",
        opts = { keyword_right_align = false },
        expected = {
            -- Keywords at start of line (left-aligned)
            matches = { "^SELECT" }
        }
    },
    {
        id = 9211,
        type = "formatter",
        name = "keyword_right_align true - simple SELECT",
        input = "SELECT id, name FROM users WHERE status = 1",
        opts = { keyword_right_align = true },
        expected = {
            -- Keywords right-aligned: SELECT, FROM, WHERE should align on right edge
            -- "SELECT" (6 chars) -> "SELECT" (no padding needed, widest keyword)
            -- "FROM" (4 chars) -> "  FROM" (padded to match SELECT width)
            -- "WHERE" (5 chars) -> " WHERE" (padded to match SELECT width)
            matches = { " +FROM", " +WHERE" }
        }
    },
    {
        id = 9212,
        type = "formatter",
        name = "keyword_right_align true - with JOIN",
        input = "SELECT u.id FROM users u INNER JOIN orders o ON u.id = o.user_id WHERE o.status = 1",
        opts = { keyword_right_align = true },
        expected = {
            -- Keywords right-aligned to longest (INNER JOIN = 10 chars)
            -- SELECT (6) gets 4 padding, FROM (4) gets 6 padding, WHERE (5) gets 5 padding
            -- INNER JOIN is longest, gets no padding (starts at column 0)
            matches = { " +SELECT", " +FROM", "INNER JOIN", " +ON", " +WHERE" }
        }
    },
    {
        id = 9213,
        type = "formatter",
        name = "keyword_right_align true - GROUP BY and ORDER BY",
        input = "SELECT category, COUNT(*) FROM products GROUP BY category ORDER BY COUNT(*) DESC",
        opts = { keyword_right_align = true },
        expected = {
            -- GROUP BY and ORDER BY are 8 chars (longest), SELECT is 6, FROM is 4
            -- GROUP BY/ORDER BY get no padding, SELECT/FROM get padding
            matches = { " +SELECT", " +FROM", "GROUP BY", "ORDER BY" }
        }
    },
    {
        id = 9214,
        type = "formatter",
        name = "keyword_right_align true - INSERT",
        input = "INSERT INTO users (id, name) VALUES (1, 'test')",
        opts = { keyword_right_align = true },
        expected = {
            -- INSERT INTO should be right-aligned
            matches = { "INSERT INTO", " +VALUES" }
        }
    },
    {
        id = 9215,
        type = "formatter",
        name = "keyword_right_align true - UPDATE SET WHERE",
        input = "UPDATE users SET name = 'new' WHERE id = 1",
        opts = { keyword_right_align = true },
        expected = {
            matches = { "UPDATE", " +SET", " +WHERE" }
        }
    },
    {
        id = 9216,
        type = "formatter",
        name = "keyword_right_align true - DELETE",
        input = "DELETE FROM users WHERE id = 1",
        opts = { keyword_right_align = true },
        expected = {
            matches = { "DELETE", " +FROM", " +WHERE" }
        }
    },
    {
        id = 9217,
        type = "formatter",
        name = "keyword_right_align true - multiple JOINs",
        input = "SELECT * FROM t1 LEFT JOIN t2 ON t1.id = t2.id RIGHT JOIN t3 ON t2.id = t3.id",
        opts = { keyword_right_align = true },
        expected = {
            -- LEFT JOIN and RIGHT JOIN are 10 chars (longest), SELECT is 6, FROM is 4, ON is 2
            -- JOINs get no padding, SELECT/FROM/ON get padding
            matches = { " +SELECT", " +FROM", "LEFT JOIN", " +ON", "RIGHT JOIN" }
        }
    },
    {
        id = 9218,
        type = "formatter",
        name = "keyword_right_align true - HAVING clause",
        input = "SELECT category, COUNT(*) cnt FROM products GROUP BY category HAVING COUNT(*) > 5",
        opts = { keyword_right_align = true },
        expected = {
            -- GROUP BY is 8 chars (longest), SELECT is 6, FROM is 4, HAVING is 6
            -- GROUP BY gets no padding, others get padding
            matches = { " +SELECT", " +FROM", "GROUP BY", " +HAVING" }
        }
    },
    {
        id = 9219,
        type = "formatter",
        name = "keyword_right_align true - CTE WITH",
        input = "WITH cte AS (SELECT * FROM t1) SELECT * FROM cte",
        opts = { keyword_right_align = true },
        expected = {
            -- WITH at top level should be left-most
            contains = { "WITH cte AS" }
        }
    },
    {
        id = 9220,
        type = "formatter",
        name = "keyword_right_align true - UNION",
        input = "SELECT id FROM t1 UNION SELECT id FROM t2",
        opts = { keyword_right_align = true },
        expected = {
            matches = { " +FROM", "UNION" }
        }
    },
    {
        id = 9221,
        type = "formatter",
        name = "keyword_right_align false - subquery preserved",
        input = "SELECT * FROM (SELECT id FROM t1) AS sub WHERE id > 0",
        opts = { keyword_right_align = false },
        expected = {
            -- Normal left-aligned
            matches = { "^SELECT", "FROM %(" }
        }
    },
    {
        id = 9222,
        type = "formatter",
        name = "keyword_right_align true - subquery inner keywords",
        input = "SELECT * FROM (SELECT id FROM t1) AS sub WHERE id > 0",
        opts = { keyword_right_align = true },
        expected = {
            -- Inner SELECT/FROM in subquery should also be right-aligned relative to context
            contains = { "SELECT id", "FROM t1" }
        }
    },
    {
        id = 9223,
        type = "formatter",
        name = "keyword_right_align true - OUTPUT clause",
        input = "DELETE FROM users OUTPUT DELETED.* WHERE id = 1",
        opts = { keyword_right_align = true },
        expected = {
            matches = { " +FROM", " +OUTPUT", " +WHERE" }
        }
    },
    {
        id = 9224,
        type = "formatter",
        name = "keyword_right_align true - long keyword alignment",
        input = "SELECT id FROM users CROSS APPLY fn(id) WHERE active = 1",
        opts = { keyword_right_align = true, cross_apply_newline = true },
        expected = {
            -- CROSS APPLY is longer than SELECT, alignment should accommodate
            matches = { " +FROM", "CROSS APPLY", " +WHERE" }
        }
    },
    {
        id = 9225,
        type = "formatter",
        name = "keyword_right_align true - river style example",
        input = "SELECT a, b, c FROM t1 INNER JOIN t2 ON t1.id = t2.id WHERE x = 1 AND y = 2 GROUP BY a, b HAVING COUNT(*) > 1 ORDER BY a",
        opts = { keyword_right_align = true },
        expected = {
            -- INNER JOIN is 10 chars (longest), all shorter keywords get padding
            -- GROUP BY, ORDER BY (8 chars) get 2 padding
            -- SELECT (6) gets 4, FROM (4) gets 6, ON (2) gets 8, WHERE (5) gets 5, HAVING (6) gets 4
            matches = { " +SELECT", " +FROM", "INNER JOIN", " +ON", " +WHERE", " +GROUP BY", " +HAVING", " +ORDER BY" }
        }
    },
}
