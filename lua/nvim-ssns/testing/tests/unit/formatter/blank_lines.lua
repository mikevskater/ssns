-- Test file: blank_lines.lua
-- IDs: 8581-8630
-- Tests: Blank line options - between statements, before clauses, after GO

return {
    -- blank_line_before_clause tests
    {
        id = 8581,
        type = "formatter",
        name = "blank_line_before_clause true",
        input = "SELECT * FROM users WHERE id = 1",
        opts = { blank_line_before_clause = true },
        expected = {
            -- Blank line appears before major clauses (FROM, WHERE)
            contains = { "SELECT *", "FROM users", "WHERE id = 1" }
        }
    },
    {
        id = 8582,
        type = "formatter",
        name = "blank_line_before_clause false (default)",
        input = "SELECT * FROM users WHERE id = 1",
        opts = { blank_line_before_clause = false },
        expected = {
            contains = { "SELECT *", "FROM users", "WHERE id = 1" }
        }
    },
    {
        id = 8583,
        type = "formatter",
        name = "blank_line_before_clause with GROUP BY and ORDER BY",
        input = "SELECT dept, COUNT(*) FROM employees GROUP BY dept ORDER BY COUNT(*) DESC",
        opts = { blank_line_before_clause = true },
        expected = {
            contains = { "FROM employees", "GROUP BY dept", "ORDER BY" }
        }
    },

    -- blank_line_between_statements tests
    {
        id = 8585,
        type = "formatter",
        name = "blank_line_between_statements 1 (default)",
        input = "SELECT 1; SELECT 2;",
        opts = { blank_line_between_statements = 1 },
        expected = {
            matches = { "SELECT 1;\n\nSELECT 2" }  -- One blank line
        }
    },
    {
        id = 8586,
        type = "formatter",
        name = "blank_line_between_statements 0",
        input = "SELECT 1; SELECT 2;",
        opts = { blank_line_between_statements = 0 },
        expected = {
            matches = { "SELECT 1;\nSELECT 2" }  -- No blank line
        }
    },
    {
        id = 8587,
        type = "formatter",
        name = "blank_line_between_statements 2",
        input = "SELECT 1; SELECT 2;",
        opts = { blank_line_between_statements = 2 },
        expected = {
            matches = { "SELECT 1;\n\n\nSELECT 2" }  -- Two blank lines
        }
    },
    {
        id = 8588,
        type = "formatter",
        name = "Multiple statements with blank lines",
        input = "SELECT 1; SELECT 2; SELECT 3;",
        opts = { blank_line_between_statements = 1 },
        expected = {
            -- All three statements should be present
            contains = { "SELECT 1;", "SELECT 2;", "SELECT 3;" }
        }
    },

    -- blank_line_after_go tests
    {
        id = 8590,
        type = "formatter",
        name = "blank_line_after_go 1 (default)",
        input = "SELECT 1\nGO\nSELECT 2",
        opts = { blank_line_after_go = 1 },
        expected = {
            matches = { "GO\n\nSELECT 2" }  -- One blank line after GO
        }
    },
    {
        id = 8591,
        type = "formatter",
        name = "blank_line_after_go 0",
        input = "SELECT 1\nGO\nSELECT 2",
        opts = { blank_line_after_go = 0 },
        expected = {
            matches = { "GO\nSELECT 2" }  -- No blank line
        }
    },
    {
        id = 8592,
        type = "formatter",
        name = "blank_line_after_go 2",
        input = "SELECT 1\nGO\nSELECT 2",
        opts = { blank_line_after_go = 2 },
        expected = {
            matches = { "GO\n\n\nSELECT 2" }  -- Two blank lines
        }
    },
    {
        id = 8593,
        type = "formatter",
        name = "Multiple GO statements",
        input = "SELECT 1\nGO\nSELECT 2\nGO\nSELECT 3",
        opts = { blank_line_after_go = 1 },
        expected = {
            contains = { "GO" }  -- Just verify GOs are present
        }
    },

    -- empty_line_before_join (covered in clause_options but also here)
    {
        id = 8595,
        type = "formatter",
        name = "empty_line_before_join with blank_line_before_clause",
        input = "SELECT * FROM users u INNER JOIN orders o ON u.id = o.user_id WHERE o.amount > 100",
        opts = {
            empty_line_before_join = true,
            blank_line_before_clause = true
        },
        expected = {
            contains = { "INNER JOIN orders o", "WHERE o.amount > 100" }
        }
    },

    -- collapse_blank_lines tests
    {
        id = 8600,
        type = "formatter",
        name = "collapse_blank_lines true - reduces multiple blank lines",
        input = "SELECT 1\n\n\n\nSELECT 2",
        opts = { collapse_blank_lines = true },
        expected = {
            -- Should not have 4 consecutive newlines
            not_contains = { "\n\n\n\n" }
        }
    },
    {
        id = 8601,
        type = "formatter",
        name = "collapse_blank_lines false - preserves multiple blank lines",
        input = "SELECT 1;\n\n\nSELECT 2",
        opts = { collapse_blank_lines = false, blank_line_between_statements = 2 },
        expected = {
            -- Multiple blank lines should be preserved
            matches = { "\n\n\n" }
        }
    },

    -- Combined blank line tests
    {
        id = 8610,
        type = "formatter",
        name = "All blank line options enabled",
        input = "SELECT * FROM users WHERE id = 1; SELECT * FROM orders WHERE total > 100",
        opts = {
            blank_line_before_clause = true,
            blank_line_between_statements = 2
        },
        expected = {
            -- Blank lines before major clauses and between statements
            matches = { "\n\n" }
        }
    },
    {
        id = 8611,
        type = "formatter",
        name = "Complex script with GO and blank lines",
        input = "CREATE TABLE test (id INT)\nGO\nINSERT INTO test (id) VALUES (1); SELECT * FROM test",
        opts = {
            blank_line_after_go = 1,
            blank_line_between_statements = 1
        },
        expected = {
            contains = { "CREATE TABLE", "GO", "INSERT INTO", "SELECT" }
        }
    },
    {
        id = 8612,
        type = "formatter",
        name = "Stored procedure with sections",
        input = "CREATE PROCEDURE TestProc AS BEGIN SELECT 1; SELECT 2; END",
        opts = { blank_line_between_statements = 1 },
        expected = {
            contains = { "CREATE PROCEDURE", "BEGIN", "SELECT 1", "SELECT 2", "END" }
        }
    },

    -- CTE with blank lines
    {
        id = 8615,
        type = "formatter",
        name = "CTE with blank_line_before_clause",
        input = "WITH cte AS (SELECT * FROM base) SELECT * FROM cte WHERE x = 1 ORDER BY y",
        opts = { blank_line_before_clause = true },
        expected = {
            -- Main query clauses should be present
            contains = { "WITH cte AS", "SELECT *", "FROM cte", "WHERE x = 1", "ORDER BY y" }
        }
    },

    -- Subquery blank lines (should NOT add blank lines inside subqueries)
    {
        id = 8620,
        type = "formatter",
        name = "No blank lines inside subquery with blank_line_before_clause",
        input = "SELECT * FROM (SELECT id FROM users WHERE active = 1) sub WHERE sub.id > 10",
        opts = { blank_line_before_clause = true },
        expected = {
            -- Inner subquery should be compact (no blank lines inside)
            -- Note: open paren can be on FROM line with SELECT on next line
            contains = { "FROM (", "SELECT id", "FROM users", "WHERE active = 1) sub" },
            -- Verify no blank lines inside subquery (inner SELECT to inner WHERE)
            not_contains = { "SELECT id\n\n", "FROM users\n\n    WHERE" }
        }
    },
    {
        id = 8621,
        type = "formatter",
        name = "Nested subqueries maintain structure",
        input = "SELECT * FROM (SELECT * FROM (SELECT 1) a) b",
        opts = { blank_line_before_clause = true },
        expected = {
            -- Subqueries are formatted with paren at end of previous line
            contains = { "FROM (", "SELECT *", "SELECT 1" },
            -- Verify no blank lines inside nested subqueries (check indented SELECT)
            not_contains = { "    SELECT *\n\n" }
        }
    },

    -- Batch separator formatting
    {
        id = 8625,
        type = "formatter",
        name = "GO on its own line",
        input = "SELECT 1 GO SELECT 2",
        expected = {
            -- GO should be on its own line
            matches = { "SELECT 1\n.*GO\n" }
        }
    },
    {
        id = 8626,
        type = "formatter",
        name = "Multiple GOs in script",
        input = "USE master\nGO\nCREATE DATABASE test\nGO\nUSE test\nGO",
        opts = { blank_line_after_go = 1 },
        expected = {
            contains = { "USE master", "GO", "CREATE DATABASE test", "USE test" }
        }
    },

    -- Edge cases
    {
        id = 8628,
        type = "formatter",
        name = "Empty statement between semicolons",
        input = "SELECT 1;; SELECT 2",
        opts = { blank_line_between_statements = 1 },
        expected = {
            contains = { "SELECT 1", "SELECT 2" }
        }
    },
    {
        id = 8629,
        type = "formatter",
        name = "Trailing semicolon only",
        input = "SELECT 1;",
        opts = { blank_line_between_statements = 1 },
        expected = {
            contains = { "SELECT 1;" }
        }
    },
    {
        id = 8630,
        type = "formatter",
        name = "Script with comments and blank lines",
        input = "-- Header comment\nSELECT 1\nGO\n-- Section 2\nSELECT 2",
        opts = { blank_line_after_go = 1 },
        expected = {
            contains = { "-- Header comment", "SELECT 1", "GO", "-- Section 2", "SELECT 2" }
        }
    },
}
