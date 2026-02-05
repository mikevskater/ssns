-- Test file: tables_provider.lua
-- IDs: 3001-3050
-- Tests: TablesProvider completion for tables, views, and synonyms
--
-- Test categories:
-- - 3001-3010: FROM clause completion
-- - 3011-3020: JOIN clause completion
-- - 3021-3030: UPDATE/DELETE/INSERT completion
-- - 3031-3040: Schema-qualified completion
-- - 3041-3050: Cross-database and edge cases

return {
  -- ========================================
  -- FROM Clause Tests (3001-3010)
  -- ========================================

  {
    id = 3001,
    type = "provider",
    provider = "tables",
    name = "Basic FROM clause completion (no prefix)",
    input = "SELECT * FROM |",
    cursor = { line = 1, col = 15 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments", "Branches"} },
    },
  },

  {
    id = 3002,
    type = "provider",
    provider = "tables",
    name = "FROM clause with partial prefix 'Emp'",
    skip = true,  -- Prefix filtering handled by blink.cmp, not provider
    input = "SELECT * FROM Emp|",
    cursor = { line = 1, col = 18 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees"}, excludes = {"Departments", "Branches"} },
    },
  },

  {
    id = 3003,
    type = "provider",
    provider = "tables",
    name = "FROM clause after existing table (comma)",
    input = "SELECT * FROM Employees, |",
    cursor = { line = 1, col = 26 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Departments", "Branches"} },
    },
  },

  {
    id = 3004,
    type = "provider",
    provider = "tables",
    name = "FROM clause in subquery",
    input = "SELECT * FROM (SELECT * FROM |) sub",
    cursor = { line = 1, col = 34 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments"} },
    },
  },

  {
    id = 3005,
    type = "provider",
    provider = "tables",
    name = "FROM clause after SELECT *",
    input = "SELECT * FROM |",
    cursor = { line = 1, col = 15 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments", "Branches"} },
    },
  },

  {
    id = 3006,
    type = "provider",
    provider = "tables",
    name = "FROM clause mode detection",
    input = "select col from |",
    cursor = { line = 1, col = 17 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments"} },
    },
  },

  {
    id = 3007,
    type = "provider",
    provider = "tables",
    name = "FROM clause with multiple existing tables",
    input = "SELECT * FROM Employees e, Departments d, |",
    cursor = { line = 1, col = 43 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Branches", "Products"} },
    },
  },

  {
    id = 3008,
    type = "provider",
    provider = "tables",
    name = "FROM clause partial match 'Depart'",
    skip = true,  -- Prefix filtering handled by blink.cmp
    input = "SELECT * FROM Depart|",
    cursor = { line = 1, col = 21 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Departments"}, excludes = {"Employees", "Branches"} },
    },
  },

  {
    id = 3009,
    type = "provider",
    provider = "tables",
    name = "FROM clause case-insensitive prefix",
    skip = true,  -- Prefix filtering handled by blink.cmp
    input = "SELECT * FROM emp|",
    cursor = { line = 1, col = 18 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees"}, excludes = {"Departments"} },
    },
  },

  {
    id = 3010,
    type = "provider",
    provider = "tables",
    name = "FROM clause with underscore prefix 'test_'",
    skip = true,  -- Prefix filtering handled by blink.cmp
    input = "SELECT * FROM test_|",
    cursor = { line = 1, col = 20 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"test_table1", "test_table2"}, excludes = {"Employees"} },
    },
  },

  -- ========================================
  -- JOIN Clause Tests (3011-3020)
  -- ========================================

  {
    id = 3011,
    type = "provider",
    provider = "tables",
    name = "Basic INNER JOIN table completion",
    input = "SELECT * FROM Employees INNER JOIN |",
    cursor = { line = 1, col = 36 },
    context = {
      mode = "join",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Departments", "Branches"} },
    },
  },

  {
    id = 3012,
    type = "provider",
    provider = "tables",
    name = "LEFT JOIN table completion",
    input = "SELECT * FROM Employees LEFT JOIN |",
    cursor = { line = 1, col = 35 },
    context = {
      mode = "join",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Departments", "Branches"} },
    },
  },

  {
    id = 3013,
    type = "provider",
    provider = "tables",
    name = "RIGHT JOIN table completion",
    input = "SELECT * FROM Employees RIGHT JOIN |",
    cursor = { line = 1, col = 36 },
    context = {
      mode = "join",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Departments", "Branches"} },
    },
  },

  {
    id = 3014,
    type = "provider",
    provider = "tables",
    name = "CROSS JOIN table completion",
    input = "SELECT * FROM Employees CROSS JOIN |",
    cursor = { line = 1, col = 36 },
    context = {
      mode = "join",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Departments", "Branches"} },
    },
  },

  {
    id = 3015,
    type = "provider",
    provider = "tables",
    name = "FULL OUTER JOIN table completion",
    input = "SELECT * FROM Employees FULL OUTER JOIN |",
    cursor = { line = 1, col = 41 },
    context = {
      mode = "join",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Departments", "Branches"} },
    },
  },

  {
    id = 3016,
    type = "provider",
    provider = "tables",
    name = "JOIN after ON clause completion (new join)",
    input = "SELECT * FROM Employees e JOIN Departments d ON e.DeptId = d.Id JOIN |",
    cursor = { line = 1, col = 70 },
    context = {
      mode = "join",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Branches", "Products"} },
    },
  },

  {
    id = 3017,
    type = "provider",
    provider = "tables",
    name = "JOIN with partial prefix",
    skip = true,  -- Prefix filtering handled by blink.cmp
    input = "SELECT * FROM Employees JOIN Dep|",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "join",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Departments"}, excludes = {"Branches", "Employees"} },
    },
  },

  {
    id = 3018,
    type = "provider",
    provider = "tables",
    name = "Multiple JOINs scenario",
    input = "SELECT * FROM Employees e JOIN Departments d ON e.DeptId = d.Id JOIN |",
    cursor = { line = 1, col = 70 },
    context = {
      mode = "join",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Branches", "Products"} },
    },
  },

  {
    id = 3019,
    type = "provider",
    provider = "tables",
    name = "Self-join scenario",
    input = "SELECT * FROM Employees e1 JOIN |",
    cursor = { line = 1, col = 33 },
    context = {
      mode = "join",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments"} },
    },
  },

  {
    id = 3020,
    type = "provider",
    provider = "tables",
    name = "JOIN in complex query",
    input = "SELECT e.Name FROM Employees e LEFT OUTER JOIN |",
    cursor = { line = 1, col = 48 },
    context = {
      mode = "join",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Departments", "Branches"} },
    },
  },

  -- ========================================
  -- UPDATE/DELETE/INSERT Tests (3021-3030)
  -- ========================================

  {
    id = 3021,
    type = "provider",
    provider = "tables",
    name = "UPDATE table completion",
    input = "UPDATE |",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "update",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments"}, excludes = {"vw_EmployeeDetails"} },
    },
  },

  {
    id = 3022,
    type = "provider",
    provider = "tables",
    name = "UPDATE with partial prefix",
    skip = true,  -- Prefix filtering handled by blink.cmp
    input = "UPDATE Emp|",
    cursor = { line = 1, col = 11 },
    context = {
      mode = "update",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees"}, excludes = {"Departments", "vw_EmployeeDetails"} },
    },
  },

  {
    id = 3023,
    type = "provider",
    provider = "tables",
    name = "DELETE FROM table completion",
    input = "DELETE FROM |",
    cursor = { line = 1, col = 13 },
    context = {
      mode = "delete",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments"}, excludes = {"vw_EmployeeDetails"} },
    },
  },

  {
    id = 3024,
    type = "provider",
    provider = "tables",
    name = "DELETE with partial prefix",
    skip = true,  -- Prefix filtering handled by blink.cmp
    input = "DELETE FROM Dep|",
    cursor = { line = 1, col = 16 },
    context = {
      mode = "delete",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Departments"}, excludes = {"Employees", "vw_EmployeeDetails"} },
    },
  },

  {
    id = 3025,
    type = "provider",
    provider = "tables",
    name = "INSERT INTO table completion",
    input = "INSERT INTO |",
    cursor = { line = 1, col = 13 },
    context = {
      mode = "insert",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments"}, excludes = {"vw_EmployeeDetails"} },
    },
  },

  {
    id = 3026,
    type = "provider",
    provider = "tables",
    name = "INSERT with partial prefix",
    skip = true,  -- Prefix filtering handled by blink.cmp
    input = "INSERT INTO Bran|",
    cursor = { line = 1, col = 17 },
    context = {
      mode = "insert",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Branches"}, excludes = {"Employees", "vw_EmployeeDetails"} },
    },
  },

  {
    id = 3027,
    type = "provider",
    provider = "tables",
    name = "UPDATE with schema prefix",
    input = "UPDATE dbo.|",
    cursor = { line = 1, col = 12 },
    context = {
      mode = "update",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments"}, excludes = {"vw_EmployeeDetails"} },
    },
  },

  {
    id = 3028,
    type = "provider",
    provider = "tables",
    name = "DELETE with schema prefix",
    input = "DELETE FROM dbo.|",
    cursor = { line = 1, col = 17 },
    context = {
      mode = "delete",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments"}, excludes = {"vw_EmployeeDetails"} },
    },
  },

  {
    id = 3029,
    type = "provider",
    provider = "tables",
    name = "INSERT with schema prefix",
    input = "INSERT INTO dbo.|",
    cursor = { line = 1, col = 17 },
    context = {
      mode = "insert",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments"}, excludes = {"vw_EmployeeDetails"} },
    },
  },

  {
    id = 3030,
    type = "provider",
    provider = "tables",
    name = "DML excludes views/synonyms",
    input = "UPDATE |",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "update",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = {
        includes = {"Employees", "Departments"},
        excludes = {"vw_EmployeeDetails", "syn_Employees"}
      },
    },
  },

  -- ========================================
  -- Schema-Qualified Tests (3031-3040)
  -- ========================================

  {
    id = 3031,
    type = "provider",
    provider = "tables",
    name = "Schema-qualified 'dbo.' completion",
    input = "SELECT * FROM dbo.|",
    cursor = { line = 1, col = 19 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments", "Branches"} },
    },
  },

  {
    id = 3032,
    type = "provider",
    provider = "tables",
    name = "Schema-qualified 'hr.' completion",
    input = "SELECT * FROM hr.|",
    cursor = { line = 1, col = 18 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"EmployeeReviews", "Salaries"}, excludes = {"Employees"} },
    },
  },

  {
    id = 3033,
    type = "provider",
    provider = "tables",
    name = "Schema-qualified 'Branch.' completion",
    input = "SELECT * FROM Branch.|",
    cursor = { line = 1, col = 22 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"BranchManagers", "BranchLocations"}, excludes = {"Employees"} },
    },
  },

  {
    id = 3034,
    type = "provider",
    provider = "tables",
    name = "Schema-qualified partial 'dbo.Emp'",
    skip = true,  -- Prefix filtering handled by blink.cmp
    input = "SELECT * FROM dbo.Emp|",
    cursor = { line = 1, col = 22 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees"}, excludes = {"Departments", "Branches"} },
    },
  },

  {
    id = 3035,
    type = "provider",
    provider = "tables",
    name = "Schema-qualified with brackets '[dbo].'",
    input = "SELECT * FROM [dbo].|",
    cursor = { line = 1, col = 21 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments"} },
    },
  },

  {
    id = 3036,
    type = "provider",
    provider = "tables",
    name = "Schema-qualified filter only matching schema",
    input = "SELECT * FROM hr.|",
    cursor = { line = 1, col = 18 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = {
        includes = {"EmployeeReviews", "Salaries"},
        excludes = {"Employees", "Departments"}
      },
    },
  },

  {
    id = 3037,
    type = "provider",
    provider = "tables",
    name = "Mixed-case schema qualification",
    input = "SELECT * FROM DBO.|",
    cursor = { line = 1, col = 19 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments"} },
    },
  },

  {
    id = 3038,
    type = "provider",
    provider = "tables",
    name = "Schema-qualified after FROM",
    input = "SELECT * FROM dbo.|",
    cursor = { line = 1, col = 19 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments", "Branches"} },
    },
  },

  {
    id = 3039,
    type = "provider",
    provider = "tables",
    name = "Schema-qualified after JOIN",
    input = "SELECT * FROM Employees JOIN dbo.|",
    cursor = { line = 1, col = 34 },
    context = {
      mode = "join",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Departments", "Branches"} },
    },
  },

  {
    id = 3040,
    type = "provider",
    provider = "tables",
    name = "Schema-qualified in INSERT",
    input = "INSERT INTO dbo.|",
    cursor = { line = 1, col = 17 },
    context = {
      mode = "insert",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments"}, excludes = {"vw_EmployeeDetails"} },
    },
  },

  -- ========================================
  -- Cross-Database & Edge Cases (3041-3050)
  -- ========================================

  {
    id = 3041,
    type = "provider",
    provider = "tables",
    name = "Cross-database 'db.dbo.' completion",
    input = "SELECT * FROM OtherDB.dbo.|",
    cursor = { line = 1, col = 27 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"ExternalTable1", "ExternalTable2"} },
    },
  },

  {
    id = 3042,
    type = "provider",
    provider = "tables",
    name = "Bracketed identifier '[My Table]'",
    input = "SELECT * FROM [My |",
    cursor = { line = 1, col = 19 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"My Table", "My Other Table"}, excludes = {"Employees"} },
    },
  },

  {
    id = 3043,
    type = "provider",
    provider = "tables",
    name = "Empty result when no tables match",
    skip = true,  -- Prefix filtering handled by blink.cmp
    input = "SELECT * FROM xyz|",
    cursor = { line = 1, col = 18 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { excludes = {"Employees", "Departments", "Branches"} },
    },
  },

  {
    id = 3044,
    type = "provider",
    provider = "tables",
    name = "Special character handling in prefix",
    skip = true,  -- Prefix filtering handled by blink.cmp, also missing test_table1/2 in mock
    input = "SELECT * FROM test_table|",
    cursor = { line = 1, col = 25 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"test_table1", "test_table2"}, excludes = {"Employees"} },
    },
  },

  {
    id = 3045,
    type = "provider",
    provider = "tables",
    name = "Very long prefix handling",
    skip = true,  -- Prefix filtering handled by blink.cmp
    input = "SELECT * FROM VeryLongTableNameThatDoesNotExist|",
    cursor = { line = 1, col = 48 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { excludes = {"Employees", "Departments"} },
    },
  },

  {
    id = 3046,
    type = "provider",
    provider = "tables",
    name = "Include views when mode is 'from'",
    input = "SELECT * FROM |",
    cursor = { line = 1, col = 15 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "vw_EmployeeDetails", "vw_DepartmentSummary"} },
    },
  },

  {
    id = 3047,
    type = "provider",
    provider = "tables",
    name = "Include synonyms when mode is 'from'",
    input = "SELECT * FROM |",
    cursor = { line = 1, col = 15 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "syn_Employees", "syn_RemoteTable"} },
    },
  },

  {
    id = 3048,
    type = "provider",
    provider = "tables",
    name = "Exclude views for DML mode",
    input = "UPDATE |",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "update",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "table",
      items = {
        includes = {"Employees", "Departments"},
        excludes = {"vw_EmployeeDetails", "vw_DepartmentSummary"}
      },
    },
  },

  {
    id = 3049,
    type = "provider",
    provider = "tables",
    name = "Filter by object type",
    skip = true,  -- Object type filtering not implemented in provider
    input = "SELECT * FROM |",
    cursor = { line = 1, col = 15 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
      filter_type = "table", -- Only show base tables
    },
    expected = {
      type = "table",
      items = {
        includes = {"Employees", "Departments"},
        excludes = {"vw_EmployeeDetails", "syn_Employees"}
      },
    },
  },

  {
    id = 3050,
    type = "provider",
    provider = "tables",
    name = "Usage-based sorting verification",
    input = "SELECT * FROM |",
    cursor = { line = 1, col = 15 },
    context = {
      mode = "from",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
      usage_stats = {
        Departments = 50,  -- Most used
        Employees = 30,
        Branches = 10,
      },
    },
    expected = {
      type = "table",
      items = { includes = {"Employees", "Departments", "Branches"} },
      -- Expected sort order: Departments, Employees, Branches (by usage)
      sort_order = {"Departments", "Employees", "Branches"},
    },
  },
}
