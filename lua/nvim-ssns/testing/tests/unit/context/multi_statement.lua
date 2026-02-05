-- Test file: multi_statement.lua
-- IDs: 3651-3700
-- Tests: Multi-statement handling and scope isolation
--
-- Test categories:
-- - 3651-3665: GO statement separation
-- - 3666-3680: Semicolon separation
-- - 3681-3695: Scope isolation
-- - 3696-3700: Edge cases

return {
  -- ================================================================
  -- GO Statement Separation (3651-3665) - 15 tests
  -- ================================================================

  {
    id = 3651,
    type = "context",
    subtype = "multi_statement",
    name = "Context after GO statement (new batch)",
    input = "SELECT * FROM Employees\nGO\nSELECT |",
    cursor = { line = 3, col = 8 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {}, -- Should NOT see Employees from previous batch
      aliases_in_scope = {},
    },
  },

  {
    id = 3652,
    type = "context",
    subtype = "multi_statement",
    name = "Context before GO statement",
    input = "SELECT e.| FROM Employees e\nGO\nSELECT * FROM Departments",
    cursor = { line = 1, col = 10 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "Employees", alias = "e" },
      },
      current_table = "e",
    },
  },

  {
    id = 3653,
    type = "context",
    subtype = "multi_statement",
    name = "GO resets table scope",
    input = "SELECT * FROM Employees e\nGO\nSELECT * FROM e.|",
    cursor = { line = 3, col = 18 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "e", alias = nil }, -- 'e' is now a table name, not alias
      },
      current_table = "e",
    },
  },

  {
    id = 3654,
    type = "context",
    subtype = "multi_statement",
    name = "GO resets alias scope",
    input = "SELECT * FROM Employees e\nGO\nSELECT e.|",
    cursor = { line = 3, col = 10 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "e", alias = nil },
      },
      current_table = "e",
    },
  },

  {
    id = 3655,
    type = "context",
    subtype = "multi_statement",
    name = "GO resets CTE scope",
    input = "WITH EmpCTE AS (SELECT * FROM Employees)\nSELECT * FROM EmpCTE\nGO\nSELECT * FROM |",
    cursor = { line = 4, col = 15 },
    expected = {
      type = "table",
      mode = "select",
      tables_in_scope = {}, -- EmpCTE no longer visible
      ctes_in_scope = {},
    },
  },

  {
    id = 3656,
    type = "context",
    subtype = "multi_statement",
    name = "Multiple GO statements",
    input = "SELECT * FROM Employees\nGO\nSELECT * FROM Departments\nGO\nSELECT * FROM |",
    cursor = { line = 5, col = 15 },
    expected = {
      type = "table",
      mode = "select",
      tables_in_scope = {},
    },
  },

  {
    id = 3657,
    type = "context",
    subtype = "multi_statement",
    name = "GO with whitespace",
    input = "SELECT * FROM Employees\n  GO  \nSELECT |",
    cursor = { line = 3, col = 8 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {},
    },
  },

  {
    id = 3658,
    type = "context",
    subtype = "multi_statement",
    name = "GO case-insensitive",
    input = "SELECT * FROM Employees\ngo\nSELECT |",
    cursor = { line = 3, col = 8 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {},
    },
  },

  {
    id = 3659,
    type = "context",
    subtype = "multi_statement",
    name = "GO at end of file",
    input = "SELECT * FROM Employees e\nSELECT e.|",
    cursor = { line = 2, col = 10 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "Employees", alias = "e" },
      },
      current_table = "e",
    },
  },

  {
    id = 3660,
    type = "context",
    subtype = "multi_statement",
    name = "GO between SELECT statements",
    input = "SELECT EmployeeID FROM Employees\nGO\nSELECT DepartmentID FROM Departments d\nWHERE d.|",
    cursor = { line = 4, col = 10 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "Departments", alias = "d" },
      },
      current_table = "d",
    },
  },

  {
    id = 3661,
    type = "context",
    subtype = "multi_statement",
    name = "GO between DML statements",
    input = "INSERT INTO Employees VALUES (1)\nGO\nUPDATE Departments SET |",
    cursor = { line = 3, col = 24 },
    expected = {
      type = "column",
      mode = "update",
      tables_in_scope = {
        { name = "Departments", alias = nil },
      },
      current_table = "Departments",
    },
  },

  {
    id = 3662,
    type = "context",
    subtype = "multi_statement",
    name = "GO with comment after",
    input = "SELECT * FROM Employees\nGO -- Start new batch\nSELECT |",
    cursor = { line = 3, col = 8 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {},
    },
  },

  {
    id = 3663,
    type = "context",
    subtype = "multi_statement",
    name = "GO with comment before",
    input = "SELECT * FROM Employees\n-- End batch\nGO\nSELECT |",
    cursor = { line = 4, col = 8 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {},
    },
  },

  {
    id = 3664,
    type = "context",
    subtype = "multi_statement",
    name = "Temp tables persist across GO",
    input = "CREATE TABLE #Temp (ID INT)\nGO\nSELECT * FROM |",
    cursor = { line = 3, col = 15 },
    expected = {
      type = "table",
      mode = "select",
      tables_in_scope = {
        { name = "#Temp", alias = nil }, -- Temp tables persist
      },
    },
  },

  {
    id = 3665,
    type = "context",
    subtype = "multi_statement",
    name = "Variables reset at GO",
    input = "DECLARE @ID INT = 1\nGO\nSELECT @|",
    cursor = { line = 3, col = 9 },
    expected = {
      type = "variable",
      mode = "select",
      variables_in_scope = {}, -- Variables don't persist across GO
    },
  },

  -- ================================================================
  -- Semicolon Separation (3666-3680) - 15 tests
  -- ================================================================

  {
    id = 3666,
    type = "context",
    subtype = "multi_statement",
    name = "Semicolon separates statements",
    input = "SELECT * FROM Employees; SELECT |",
    cursor = { line = 1, col = 33 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {}, -- New statement after semicolon
    },
  },

  {
    id = 3667,
    type = "context",
    subtype = "multi_statement",
    name = "Multiple semicolons",
    input = "SELECT * FROM Employees; SELECT * FROM Departments; SELECT |",
    cursor = { line = 1, col = 60 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {},
    },
  },

  {
    id = 3668,
    type = "context",
    subtype = "multi_statement",
    name = "Semicolon with newline",
    input = "SELECT * FROM Employees;\nSELECT |",
    cursor = { line = 2, col = 8 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {},
    },
  },

  {
    id = 3669,
    type = "context",
    subtype = "multi_statement",
    name = "Semicolon without newline",
    input = "SELECT * FROM Employees;SELECT |",
    cursor = { line = 1, col = 32 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {},
    },
  },

  {
    id = 3670,
    type = "context",
    subtype = "multi_statement",
    name = "Semicolon in string (no split)",
    input = "SELECT 'test;value' AS Text FROM Employees e WHERE e.|",
    cursor = { line = 1, col = 54 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "Employees", alias = "e" },
      },
      current_table = "e",
    },
  },

  {
    id = 3671,
    type = "context",
    subtype = "multi_statement",
    name = "Context after semicolon",
    input = "SELECT EmployeeID FROM Employees; SELECT DepartmentID FROM |",
    cursor = { line = 1, col = 60 },
    expected = {
      type = "table",
      mode = "select",
      tables_in_scope = {},
    },
  },

  {
    id = 3672,
    type = "context",
    subtype = "multi_statement",
    name = "Tables from previous statement",
    input = "SELECT * FROM Employees e; SELECT * FROM Departments d WHERE d.|",
    cursor = { line = 1, col = 64 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "Departments", alias = "d" },
      },
      current_table = "d",
    },
  },

  {
    id = 3673,
    type = "context",
    subtype = "multi_statement",
    name = "Aliases from previous statement not visible",
    input = "SELECT * FROM Employees e; SELECT e.|",
    cursor = { line = 1, col = 37 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "e", alias = nil }, -- 'e' is table name, not previous alias
      },
      current_table = "e",
    },
  },

  {
    id = 3674,
    type = "context",
    subtype = "multi_statement",
    name = "CTE visible before semicolon",
    input = "WITH EmpCTE AS (SELECT * FROM Employees) SELECT * FROM EmpCTE WHERE |",
    cursor = { line = 1, col = 69 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "EmpCTE", alias = nil, is_cte = true },
      },
      ctes_in_scope = { "EmpCTE" },
    },
  },

  {
    id = 3675,
    type = "context",
    subtype = "multi_statement",
    name = "CTE not visible after semicolon",
    input = "WITH EmpCTE AS (SELECT * FROM Employees) SELECT * FROM EmpCTE; SELECT * FROM |",
    cursor = { line = 1, col = 78 },
    expected = {
      type = "table",
      mode = "select",
      tables_in_scope = {},
      ctes_in_scope = {}, -- CTE scope ended at semicolon
    },
  },

  {
    id = 3676,
    type = "context",
    subtype = "multi_statement",
    name = "Nested semicolons in function",
    input = "CREATE FUNCTION GetEmp() RETURNS INT AS BEGIN DECLARE @x INT; SET @x = 1; RETURN @x; END; SELECT |",
    cursor = { line = 1, col = 96 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {},
    },
  },

  {
    id = 3677,
    type = "context",
    subtype = "multi_statement",
    name = "Semicolon in dynamic SQL",
    input = "EXEC('SELECT * FROM Employees; SELECT * FROM Departments'); SELECT |",
    cursor = { line = 1, col = 68 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {},
    },
  },

  {
    id = 3678,
    type = "context",
    subtype = "multi_statement",
    name = "Multiple statements on same line",
    input = "DECLARE @x INT; SET @x = 1; SELECT @|",
    cursor = { line = 1, col = 37 },
    expected = {
      type = "variable",
      mode = "select",
      variables_in_scope = {
        { name = "@x", type = "INT" },
      },
    },
  },

  {
    id = 3679,
    type = "context",
    subtype = "multi_statement",
    name = "Statement continuation without semicolon",
    input = "SELECT * FROM Employees\nWHERE |",
    cursor = { line = 2, col = 7 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "Employees", alias = nil },
      },
    },
  },

  {
    id = 3680,
    type = "context",
    subtype = "multi_statement",
    name = "Partial statement after semicolon",
    input = "SELECT * FROM Employees; UPDATE Departments SET |",
    cursor = { line = 1, col = 49 },
    expected = {
      type = "column",
      mode = "update",
      tables_in_scope = {
        { name = "Departments", alias = nil },
      },
      current_table = "Departments",
    },
  },

  -- ================================================================
  -- Scope Isolation (3681-3695) - 15 tests
  -- ================================================================

  {
    id = 3681,
    type = "context",
    subtype = "multi_statement",
    name = "CTE scope limited to single statement",
    input = "WITH EmpCTE AS (SELECT * FROM Employees) SELECT * FROM EmpCTE;\nWITH DeptCTE AS (SELECT * FROM Departments) SELECT * FROM |",
    cursor = { line = 2, col = 60 },
    expected = {
      type = "table",
      mode = "select",
      ctes_in_scope = { "DeptCTE" }, -- Only current CTE visible
    },
  },

  {
    id = 3682,
    type = "context",
    subtype = "multi_statement",
    name = "Alias scope isolation between statements",
    input = "SELECT * FROM Employees e; SELECT * FROM Departments d WHERE d.|",
    cursor = { line = 1, col = 64 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "Departments", alias = "d" },
      },
      aliases_in_scope = { "d" }, -- Only 'd', not 'e'
      current_table = "d",
    },
  },

  {
    id = 3683,
    type = "context",
    subtype = "multi_statement",
    name = "Subquery scope isolation",
    input = "SELECT * FROM (SELECT * FROM Employees e) sub WHERE |",
    cursor = { line = 1, col = 53 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "sub", alias = nil, is_derived = true },
      },
      -- 'e' not visible outside subquery
    },
  },

  {
    id = 3684,
    type = "context",
    subtype = "multi_statement",
    name = "Derived table alias scope",
    input = "SELECT dt.| FROM (SELECT EmployeeID FROM Employees) dt",
    cursor = { line = 1, col = 11 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "dt", alias = nil, is_derived = true },
      },
      current_table = "dt",
    },
  },

  {
    id = 3685,
    type = "context",
    subtype = "multi_statement",
    name = "CROSS APPLY scope",
    input = "SELECT * FROM Employees e CROSS APPLY (SELECT * FROM Departments WHERE DepartmentID = e.DepartmentID) d WHERE d.|",
    cursor = { line = 1, col = 114 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "Employees", alias = "e" },
        { name = "d", alias = nil, is_derived = true },
      },
      current_table = "d",
    },
  },

  {
    id = 3686,
    type = "context",
    subtype = "multi_statement",
    name = "Nested subquery scopes",
    input = "SELECT * FROM (SELECT * FROM (SELECT * FROM Employees e1) e2) e3 WHERE e3.|",
    cursor = { line = 1, col = 76 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "e3", alias = nil, is_derived = true },
      },
      current_table = "e3",
    },
  },

  {
    id = 3687,
    type = "context",
    subtype = "multi_statement",
    name = "Multiple CTEs in same statement",
    input = "WITH CTE1 AS (SELECT * FROM Employees), CTE2 AS (SELECT * FROM Departments) SELECT * FROM |",
    cursor = { line = 1, col = 92 },
    expected = {
      type = "table",
      mode = "select",
      ctes_in_scope = { "CTE1", "CTE2" },
    },
  },

  {
    id = 3688,
    type = "context",
    subtype = "multi_statement",
    name = "CTE referencing previous CTE",
    input = "WITH CTE1 AS (SELECT * FROM Employees), CTE2 AS (SELECT * FROM CTE1 WHERE |)",
    cursor = { line = 1, col = 76 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "CTE1", alias = nil, is_cte = true },
      },
      ctes_in_scope = { "CTE1" }, -- CTE1 visible in CTE2 definition
    },
  },

  {
    id = 3689,
    type = "context",
    subtype = "multi_statement",
    name = "Recursive CTE scope",
    input = "WITH RecCTE AS (SELECT EmployeeID FROM Employees UNION ALL SELECT EmployeeID FROM RecCTE WHERE |)",
    cursor = { line = 1, col = 96 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "RecCTE", alias = nil, is_cte = true },
      },
      ctes_in_scope = { "RecCTE" },
    },
  },

  {
    id = 3690,
    type = "context",
    subtype = "multi_statement",
    name = "Temp table global scope",
    input = "CREATE TABLE #Temp (ID INT); SELECT * FROM Employees; SELECT * FROM |",
    cursor = { line = 1, col = 69 },
    expected = {
      type = "table",
      mode = "select",
      tables_in_scope = {
        { name = "#Temp", alias = nil }, -- Temp table visible across statements
      },
    },
  },

  {
    id = 3691,
    type = "context",
    subtype = "multi_statement",
    name = "Table variable scope",
    input = "DECLARE @TableVar TABLE (ID INT); SELECT * FROM Employees; SELECT * FROM |",
    cursor = { line = 1, col = 74 },
    expected = {
      type = "table",
      mode = "select",
      tables_in_scope = {
        { name = "@TableVar", alias = nil }, -- Table variable visible in batch
      },
    },
  },

  {
    id = 3692,
    type = "context",
    subtype = "multi_statement",
    name = "Parameter scope across statements",
    input = "CREATE PROCEDURE Test @ID INT AS BEGIN SELECT * FROM Employees WHERE EmployeeID = @ID; SELECT @| END",
    cursor = { line = 1, col = 96 },
    expected = {
      type = "variable",
      mode = "select",
      variables_in_scope = {
        { name = "@ID", type = "INT" },
      },
    },
  },

  {
    id = 3693,
    type = "context",
    subtype = "multi_statement",
    name = "UNION scope handling",
    input = "SELECT * FROM Employees e1 UNION SELECT * FROM Employees e2 WHERE e2.|",
    cursor = { line = 1, col = 70 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "Employees", alias = "e2" },
      },
      current_table = "e2",
    },
  },

  {
    id = 3694,
    type = "context",
    subtype = "multi_statement",
    name = "EXCEPT/INTERSECT scope",
    input = "SELECT * FROM Employees e1 EXCEPT SELECT * FROM Employees e2 WHERE e2.|",
    cursor = { line = 1, col = 71 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "Employees", alias = "e2" },
      },
      current_table = "e2",
    },
  },

  {
    id = 3695,
    type = "context",
    subtype = "multi_statement",
    name = "INSERT SELECT scope",
    input = "INSERT INTO Archive SELECT * FROM Employees e WHERE e.|",
    cursor = { line = 1, col = 55 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {
        { name = "Employees", alias = "e" },
      },
      current_table = "e",
    },
  },

  -- ================================================================
  -- Edge Cases (3696-3700) - 5 tests
  -- ================================================================

  {
    id = 3696,
    type = "context",
    subtype = "multi_statement",
    name = "Empty statement between separators",
    input = "SELECT * FROM Employees;; SELECT |",
    cursor = { line = 1, col = 34 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {},
    },
  },

  {
    id = 3697,
    type = "context",
    subtype = "multi_statement",
    name = "Comment-only statement",
    input = "SELECT * FROM Employees; -- Just a comment\nSELECT |",
    cursor = { line = 2, col = 8 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {},
    },
  },

  {
    id = 3698,
    type = "context",
    subtype = "multi_statement",
    name = "Very long multi-statement script",
    input = "SELECT * FROM T1; SELECT * FROM T2; SELECT * FROM T3; SELECT * FROM T4; SELECT * FROM T5; SELECT |",
    cursor = { line = 1, col = 97 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {},
    },
  },

  {
    id = 3699,
    type = "context",
    subtype = "multi_statement",
    name = "Nested batches (dynamic SQL)",
    input = "DECLARE @SQL NVARCHAR(MAX) = 'SELECT * FROM Employees; SELECT * FROM Departments';\nEXEC(@SQL);\nSELECT |",
    cursor = { line = 3, col = 8 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {},
      variables_in_scope = {
        { name = "@SQL", type = "NVARCHAR" },
      },
    },
  },

  {
    id = 3700,
    type = "context",
    subtype = "multi_statement",
    name = "Mixed statement types",
    input = "INSERT INTO Employees VALUES (1); UPDATE Departments SET Name = 'IT'; DELETE FROM Projects; SELECT |",
    cursor = { line = 1, col = 99 },
    expected = {
      type = "column",
      mode = "select",
      tables_in_scope = {},
    },
  },
}
