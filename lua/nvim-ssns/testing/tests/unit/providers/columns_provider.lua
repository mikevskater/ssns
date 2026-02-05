-- Test file: columns_provider.lua
-- IDs: 3051-3200
-- Tests: ColumnsProvider completion for column names with context awareness
--
-- Test categories:
-- - 3051-3070: SELECT unqualified columns
-- - 3071-3095: Alias-qualified columns (table.| or alias.|)
-- - 3096-3120: WHERE clause columns with type compatibility
-- - 3121-3145: ON clause columns with fuzzy matching
-- - 3146-3160: ORDER BY / GROUP BY columns
-- - 3161-3175: INSERT column list
-- - 3176-3190: VALUES clause hints
-- - 3191-3200: Edge cases
--
-- NOTE: This file contains tests 3051-3100. Additional tests continue in this file.

return {
  -- =========================================================================
  -- SELECT Unqualified Columns (3051-3070)
  -- =========================================================================

  {
    id = 3051,
    type = "provider",
    provider = "columns",
    name = "Basic SELECT column completion from single table",
    input = "SELECT | FROM Employees",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName", "HireDate", "DepartmentID" },
        excludes = { "DepartmentName", "ProductID" },
      },
    },
  },

  {
    id = 3052,
    type = "provider",
    provider = "columns",
    name = "SELECT with partial prefix returns all columns (filtering done by framework)",
    input = "SELECT First| FROM Employees",
    cursor = { line = 1, col = 13 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      prefix = "First",
    },
    expected = {
      type = "column",
      items = {
        -- Provider returns all columns; prefix filtering is done by completion framework
        includes = { "FirstName", "LastName", "EmployeeID" },
      },
    },
  },

  {
    id = 3053,
    type = "provider",
    provider = "columns",
    name = "SELECT with multiple tables shows all columns",
    input = "SELECT | FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "DepartmentID", "DepartmentName" },
      },
    },
  },

  {
    id = 3054,
    type = "provider",
    provider = "columns",
    name = "SELECT after existing column",
    input = "SELECT FirstName, | FROM Employees",
    cursor = { line = 1, col = 19 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "LastName", "EmployeeID", "HireDate" },
        excludes = { "DepartmentName" },
      },
    },
  },

  {
    id = 3055,
    type = "provider",
    provider = "columns",
    name = "SELECT * expansion alternative",
    input = "SELECT *| FROM Employees",
    cursor = { line = 1, col = 9 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName", "HireDate", "DepartmentID" },
      },
    },
  },

  {
    id = 3056,
    type = "provider",
    provider = "columns",
    name = "SELECT with table alias in scope",
    input = "SELECT | FROM Employees e",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = "e", schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3057,
    type = "provider",
    provider = "columns",
    name = "Primary key columns in results",
    input = "SELECT | FROM Employees",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID" },  -- Primary key
      },
    },
  },

  {
    id = 3058,
    type = "provider",
    provider = "columns",
    name = "SELECT case-insensitive prefix returns all columns",
    input = "SELECT FIRST| FROM Employees",
    cursor = { line = 1, col = 13 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      prefix = "FIRST",
    },
    expected = {
      type = "column",
      items = {
        -- Provider returns all columns; prefix filtering done by framework
        includes = { "FirstName", "LastName", "EmployeeID" },
      },
    },
  },

  {
    id = 3059,
    type = "provider",
    provider = "columns",
    name = "SELECT with prefix returns all columns including IsActive",
    input = "SELECT Is| FROM Employees",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      prefix = "Is",
    },
    expected = {
      type = "column",
      items = {
        -- Provider returns all columns; prefix filtering done by framework
        includes = { "IsActive", "FirstName", "EmployeeID" },
      },
    },
  },

  {
    id = 3060,
    type = "provider",
    provider = "columns",
    name = "SELECT returns all columns (already_selected filtering done by framework)",
    input = "SELECT FirstName, LastName, | FROM Employees",
    cursor = { line = 1, col = 29 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      already_selected = { "FirstName", "LastName" },
    },
    expected = {
      type = "column",
      items = {
        -- Provider returns all columns; filtering done by framework
        includes = { "EmployeeID", "HireDate", "DepartmentID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3061,
    type = "provider",
    provider = "columns",
    name = "SELECT from view columns",
    input = "SELECT | FROM vw_ActiveEmployees",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "vw_ActiveEmployees", alias = nil, schema = "dbo", object_type = "view" } },
    },
    expected = {
      type = "column",
      items = {
        -- vw_ActiveEmployees columns from database_structure.md
        includes = { "EmployeeID", "FirstName", "LastName", "Email", "DepartmentID", "HireDate", "Salary" },
      },
    },
  },

  {
    id = 3062,
    type = "provider",
    provider = "columns",
    name = "SELECT with schema-qualified table",
    input = "SELECT | FROM dbo.Employees",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3063,
    type = "provider",
    provider = "columns",
    name = "SELECT aggregate context shows columns",
    input = "SELECT COUNT(|) FROM Employees",
    cursor = { line = 1, col = 14 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      in_aggregate = true,
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3064,
    type = "provider",
    provider = "columns",
    name = "SELECT DISTINCT columns",
    input = "SELECT DISTINCT | FROM Employees",
    cursor = { line = 1, col = 17 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3065,
    type = "provider",
    provider = "columns",
    name = "SELECT TOP N columns",
    input = "SELECT TOP 10 | FROM Employees",
    cursor = { line = 1, col = 15 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3066,
    type = "provider",
    provider = "columns",
    name = "SELECT with computed column",
    input = "SELECT FirstName + ' ' + LastName AS FullName, | FROM Employees",
    cursor = { line = 1, col = 48 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "HireDate", "DepartmentID" },
      },
    },
  },

  {
    id = 3067,
    type = "provider",
    provider = "columns",
    name = "SELECT with nullable column indication",
    input = "SELECT | FROM Employees",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "Email" },  -- Nullable column
      },
      metadata = {
        nullable_indicator = true,
      },
    },
  },

  {
    id = 3068,
    type = "provider",
    provider = "columns",
    name = "SELECT from joined tables all columns",
    input = "SELECT | FROM Employees e INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "DepartmentID", "DepartmentName", "Location" },
      },
    },
  },

  {
    id = 3069,
    type = "provider",
    provider = "columns",
    name = "SELECT with CTE columns",
    skip = true,  -- CTE column resolution requires context setup not available in unit tests
    input = "WITH EmployeeCTE AS (SELECT EmployeeID, FirstName FROM Employees) SELECT | FROM EmployeeCTE",
    cursor = { line = 1, col = 78 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "EmployeeCTE", alias = nil, schema = nil, object_type = "cte" } },
      cte_columns = { "EmployeeID", "FirstName" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName" },
        excludes = { "LastName", "DepartmentID" },
      },
    },
  },

  {
    id = 3070,
    type = "provider",
    provider = "columns",
    name = "SELECT with temp table columns",
    skip = true,  -- Temp table column resolution requires context setup not available in unit tests
    input = "SELECT | FROM #TempEmployees",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "#TempEmployees", alias = nil, schema = "dbo", object_type = "temp_table" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "TempID", "TempName", "TempValue" },
      },
    },
  },

  -- =========================================================================
  -- Alias-Qualified Columns (3071-3095)
  -- =========================================================================

  {
    id = 3071,
    type = "provider",
    provider = "columns",
    name = "Basic alias.| completion (e.| -> Employee columns)",
    input = "SELECT e.| FROM Employees e",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = "e", schema = "dbo" } },
      table_ref = "e",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName", "HireDate", "DepartmentID" },
        excludes = { "DepartmentName", "ProductID" },
      },
    },
  },

  {
    id = 3072,
    type = "provider",
    provider = "columns",
    name = "Table name.| completion (Employees.|)",
    input = "SELECT Employees.| FROM Employees",
    cursor = { line = 1, col = 18 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      table_ref = "Employees",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3073,
    type = "provider",
    provider = "columns",
    name = "Schema.table.| completion (dbo.Employees.|)",
    input = "SELECT dbo.Employees.| FROM dbo.Employees",
    cursor = { line = 1, col = 22 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      table_ref = "dbo.Employees",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3074,
    type = "provider",
    provider = "columns",
    name = "Alias resolution single table",
    input = "SELECT e.| FROM Employees e WHERE e.DepartmentID = 1",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = "e", schema = "dbo" } },
      table_ref = "e",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName", "DepartmentID" },
      },
    },
  },

  {
    id = 3075,
    type = "provider",
    provider = "columns",
    name = "Alias resolution with multiple tables",
    input = "SELECT d.| FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      table_ref = "d",
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "DepartmentName", "Location" },
        excludes = { "EmployeeID", "FirstName" },
      },
    },
  },

  {
    id = 3076,
    type = "provider",
    provider = "columns",
    name = "Non-existent alias returns empty",
    input = "SELECT x.| FROM Employees e",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = "e", schema = "dbo" } },
      table_ref = "x",
    },
    expected = {
      type = "column",
      items = {
        includes = {},
      },
    },
  },

  {
    id = 3077,
    type = "provider",
    provider = "columns",
    name = "Case-insensitive alias 'E.' matches 'e'",
    input = "SELECT E.| FROM Employees e",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = "e", schema = "dbo" } },
      table_ref = "E",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3078,
    type = "provider",
    provider = "columns",
    name = "Partial column after dot (e.First|)",
    skip = true,  -- Prefix filtering handled by blink.cmp
    input = "SELECT e.First| FROM Employees e",
    cursor = { line = 1, col = 15 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = "e", schema = "dbo" } },
      table_ref = "e",
      prefix = "First",
    },
    expected = {
      type = "column",
      items = {
        includes = { "FirstName" },
        excludes = { "LastName", "EmployeeID" },
      },
    },
  },

  {
    id = 3079,
    type = "provider",
    provider = "columns",
    name = "Qualified column with schema prefix",
    input = "SELECT dbo.| FROM Employees",
    cursor = { line = 1, col = 12 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      table_ref = "dbo",
    },
    expected = {
      type = "table",  -- Schema prefix suggests table completion
      items = {
        includes = { "Employees", "Departments", "Products" },
      },
    },
  },

  {
    id = 3080,
    type = "provider",
    provider = "columns",
    name = "Database.schema.table.| columns",
    input = "SELECT vim_dadbod_test.dbo.Employees.| FROM vim_dadbod_test.dbo.Employees",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo", database = "vim_dadbod_test" } },
      table_ref = "vim_dadbod_test.dbo.Employees",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3081,
    type = "provider",
    provider = "columns",
    name = "Bracketed alias [e].| columns",
    input = "SELECT [e].| FROM Employees [e]",
    cursor = { line = 1, col = 12 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = "e", schema = "dbo" } },
      table_ref = "e",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3082,
    type = "provider",
    provider = "columns",
    name = "Bracketed table [Employees].| columns",
    input = "SELECT [Employees].| FROM [Employees]",
    cursor = { line = 1, col = 20 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      table_ref = "Employees",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3083,
    type = "provider",
    provider = "columns",
    name = "Mixed case alias resolution",
    input = "SELECT EMP.| FROM Employees EMP",
    cursor = { line = 1, col = 12 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = "EMP", schema = "dbo" } },
      table_ref = "EMP",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3084,
    type = "provider",
    provider = "columns",
    name = "Alias shadows table name",
    input = "SELECT Employees.| FROM Departments Employees",
    cursor = { line = 1, col = 18 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Departments", alias = "Employees", schema = "dbo" } },
      table_ref = "Employees",
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "DepartmentName", "Location" },
        excludes = { "EmployeeID", "FirstName" },
      },
    },
  },

  {
    id = 3085,
    type = "provider",
    provider = "columns",
    name = "Self-join with different aliases",
    input = "SELECT e1.| FROM Employees e1 JOIN Employees e2 ON e1.ManagerID = e2.EmployeeID",
    cursor = { line = 1, col = 11 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e1", schema = "dbo" },
        { name = "Employees", alias = "e2", schema = "dbo" },
      },
      table_ref = "e1",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName", "ManagerID" },
      },
    },
  },

  {
    id = 3086,
    type = "provider",
    provider = "columns",
    name = "Alias defined in subquery",
    input = "SELECT sub.| FROM (SELECT EmployeeID, FirstName FROM Employees) sub",
    cursor = { line = 1, col = 12 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "sub", alias = "sub", schema = nil, object_type = "subquery" } },
      table_ref = "sub",
      subquery_columns = { "EmployeeID", "FirstName" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName" },
        excludes = { "LastName", "DepartmentID" },
      },
    },
  },

  {
    id = 3087,
    type = "provider",
    provider = "columns",
    name = "Outer query alias not visible in subquery",
    input = "SELECT * FROM Employees e WHERE EXISTS (SELECT e.|)",
    cursor = { line = 1, col = 50 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = "e", schema = "dbo" } },
      table_ref = "e",
      in_subquery = true,
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3088,
    type = "provider",
    provider = "columns",
    name = "Subquery alias in outer query",
    input = "SELECT outer_sub.| FROM (SELECT EmployeeID FROM Employees) outer_sub",
    cursor = { line = 1, col = 18 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "outer_sub", alias = "outer_sub", schema = nil, object_type = "subquery" } },
      table_ref = "outer_sub",
      subquery_columns = { "EmployeeID" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID" },
        excludes = { "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3089,
    type = "provider",
    provider = "columns",
    name = "CTE alias.| columns",
    input = "WITH EmployeeCTE AS (SELECT EmployeeID, FirstName FROM Employees) SELECT cte.| FROM EmployeeCTE cte",
    cursor = { line = 1, col = 82 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "EmployeeCTE", alias = "cte", schema = nil, object_type = "cte" } },
      table_ref = "cte",
      cte_columns = { "EmployeeID", "FirstName" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName" },
        excludes = { "LastName", "DepartmentID" },
      },
    },
  },

  {
    id = 3090,
    type = "provider",
    provider = "columns",
    name = "Temp table alias.| columns",
    input = "SELECT t.| FROM #TempEmployees t",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "#TempEmployees", alias = "t", schema = "dbo", object_type = "temp_table" } },
      table_ref = "t",
    },
    expected = {
      type = "column",
      items = {
        includes = { "TempID", "TempName", "TempValue" },
      },
    },
  },

  {
    id = 3091,
    type = "provider",
    provider = "columns",
    name = "View alias.| columns",
    input = "SELECT v.| FROM vw_ActiveEmployees v",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "vw_ActiveEmployees", alias = "v", schema = "dbo", object_type = "view" } },
      table_ref = "v",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },  -- Actual view columns
      },
    },
  },

  {
    id = 3092,
    type = "provider",
    provider = "columns",
    name = "Synonym alias.| columns",
    input = "SELECT s.| FROM syn_Employees s",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "syn_Employees", alias = "s", schema = "dbo", object_type = "synonym", base_object = "Employees" } },
      table_ref = "s",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3093,
    type = "provider",
    provider = "columns",
    name = "Three-part name columns",
    input = "SELECT TestDB.dbo.Employees.| FROM TestDB.dbo.Employees",
    cursor = { line = 1, col = 29 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo", database = "TestDB" } },
      table_ref = "TestDB.dbo.Employees",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3094,
    type = "provider",
    provider = "columns",
    name = "Four-part name (linked server) columns",
    input = "SELECT LinkedServer.TestDB.dbo.Employees.| FROM LinkedServer.TestDB.dbo.Employees",
    cursor = { line = 1, col = 42 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo", database = "TestDB", server = "LinkedServer" } },
      table_ref = "LinkedServer.TestDB.dbo.Employees",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3095,
    type = "provider",
    provider = "columns",
    name = "Alias with numeric suffix (e1.|)",
    input = "SELECT e1.| FROM Employees e1",
    cursor = { line = 1, col = 11 },
    context = {
      mode = "qualified",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = "e1", schema = "dbo" } },
      table_ref = "e1",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },
      },
    },
  },

  -- =========================================================================
  -- WHERE Clause Columns (3096-3100) - First 5 tests
  -- =========================================================================

  {
    id = 3096,
    type = "provider",
    provider = "columns",
    name = "Basic WHERE column completion",
    input = "SELECT * FROM Employees WHERE |",
    cursor = { line = 1, col = 31 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName", "DepartmentID" },
      },
    },
  },

  {
    id = 3097,
    type = "provider",
    provider = "columns",
    name = "WHERE with left-side INT column",
    skip = true,  -- Type compatibility filtering not implemented in provider
    input = "SELECT * FROM Employees WHERE EmployeeID = |",
    cursor = { line = 1, col = 44 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      left_side = { column_name = "EmployeeID", table_ref = nil, data_type = "int" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "ManagerID" },  -- Other INT columns
        excludes = { "FirstName", "LastName" },  -- VARCHAR columns
      },
      type_compatibility = {
        preferred_type = "int",
        compatible_types = { "int", "bigint", "smallint", "tinyint" },
      },
    },
  },

  {
    id = 3098,
    type = "provider",
    provider = "columns",
    name = "WHERE type warning INT vs VARCHAR",
    skip = true,  -- Type warning feature not yet implemented
    input = "SELECT * FROM Employees WHERE EmployeeID = FirstName",
    cursor = { line = 1, col = 53 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      left_side = { column_name = "EmployeeID", table_ref = nil, data_type = "int" },
      right_side = { column_name = "FirstName", table_ref = nil, data_type = "varchar" },
    },
    expected = {
      type = "warning",
      message = "Type mismatch: EmployeeID (int) compared with FirstName (varchar)",
      severity = "warning",
    },
  },

  {
    id = 3099,
    type = "provider",
    provider = "columns",
    name = "WHERE compatible types INT vs BIGINT",
    skip = true,  -- Type compatibility filtering not implemented in provider
    input = "SELECT * FROM Employees e JOIN Orders o ON e.EmployeeID = o.EmployeeID WHERE e.EmployeeID = o.|",
    cursor = { line = 1, col = 99 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Orders", alias = "o", schema = "dbo" },
      },
      left_side = { column_name = "EmployeeID", table_ref = "e", data_type = "int" },
      table_ref = "o",
    },
    expected = {
      type = "column",
      items = {
        includes = { "OrderID", "EmployeeID" },  -- INT/BIGINT columns from Orders
        excludes = { "OrderDate", "CustomerName" },  -- DATE/VARCHAR columns
      },
      type_compatibility = {
        preferred_type = "int",
        compatible_types = { "int", "bigint", "smallint", "tinyint" },
      },
    },
  },

  {
    id = 3100,
    type = "provider",
    provider = "columns",
    name = "WHERE after AND operator",
    input = "SELECT * FROM Employees WHERE DepartmentID = 1 AND |",
    cursor = { line = 1, col = 52 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "IsActive", "HireDate" },
      },
    },
  },

  -- =========================================================================
  -- WHERE Clause Columns Continued (3101-3120)
  -- =========================================================================

  {
    id = 3101,
    type = "provider",
    provider = "columns",
    name = "WHERE type warning DATE vs INT",
    skip = true,  -- Type warning feature not yet implemented
    input = "SELECT * FROM Employees WHERE HireDate = EmployeeID",
    cursor = { line = 1, col = 52 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      left_side = { column_name = "HireDate", table_ref = nil, data_type = "date" },
      right_side = { column_name = "EmployeeID", table_ref = nil, data_type = "int" },
    },
    expected = {
      type = "warning",
      message = "Type mismatch: HireDate (date) compared with EmployeeID (int)",
      severity = "warning",
    },
  },

  {
    id = 3102,
    type = "provider",
    provider = "columns",
    name = "WHERE type warning VARCHAR vs DECIMAL",
    skip = true,  -- Type warning feature not yet implemented
    input = "SELECT * FROM Products WHERE Name = Price",
    cursor = { line = 1, col = 41 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Products", alias = nil, schema = "dbo" } },
      left_side = { column_name = "Name", table_ref = nil, data_type = "varchar" },
      right_side = { column_name = "Price", table_ref = nil, data_type = "decimal" },
    },
    expected = {
      type = "warning",
      message = "Type mismatch: Name (varchar) compared with Price (decimal)",
      severity = "warning",
    },
  },

  {
    id = 3103,
    type = "provider",
    provider = "columns",
    name = "WHERE with qualified left side (e.DepartmentID =)",
    skip = true,  -- Type compatibility filtering not implemented in provider
    input = "SELECT * FROM Employees e WHERE e.DepartmentID = |",
    cursor = { line = 1, col = 50 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = "e", schema = "dbo" } },
      left_side = { column_name = "DepartmentID", table_ref = "e", data_type = "int" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "ManagerID" },  -- INT columns
        excludes = { "FirstName", "HireDate" },
      },
      type_compatibility = {
        preferred_type = "int",
        compatible_types = { "int", "bigint", "smallint", "tinyint" },
      },
    },
  },

  {
    id = 3104,
    type = "provider",
    provider = "columns",
    name = "WHERE OR operator columns",
    input = "SELECT * FROM Employees WHERE DepartmentID = 1 OR |",
    cursor = { line = 1, col = 51 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "IsActive", "HireDate" },
      },
    },
  },

  {
    id = 3105,
    type = "provider",
    provider = "columns",
    name = "WHERE BETWEEN columns",
    skip = true,  -- Type compatibility filtering not implemented in provider
    input = "SELECT * FROM Employees WHERE HireDate BETWEEN '2020-01-01' AND |",
    cursor = { line = 1, col = 65 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      left_side = { column_name = "HireDate", table_ref = nil, data_type = "date" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "HireDate" },  -- DATE columns
        excludes = { "EmployeeID", "FirstName" },
      },
      type_compatibility = {
        preferred_type = "date",
        compatible_types = { "date", "datetime", "datetime2", "smalldatetime" },
      },
    },
  },

  {
    id = 3106,
    type = "provider",
    provider = "columns",
    name = "WHERE IN (subquery) columns",
    input = "SELECT * FROM Employees WHERE DepartmentID IN (SELECT | FROM Departments)",
    cursor = { line = 1, col = 59 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Departments", alias = nil, schema = "dbo" } },
      in_subquery = true,
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "DepartmentName", "Location" },
      },
    },
  },

  {
    id = 3107,
    type = "provider",
    provider = "columns",
    name = "WHERE EXISTS columns",
    input = "SELECT * FROM Employees e WHERE EXISTS (SELECT 1 FROM Departments d WHERE d.DepartmentID = |)",
    cursor = { line = 1, col = 94 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      left_side = { column_name = "DepartmentID", table_ref = "d", data_type = "int" },
      in_subquery = true,
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "EmployeeID" },  -- INT columns from both tables
        excludes = { "FirstName", "DepartmentName" },
      },
    },
  },

  {
    id = 3108,
    type = "provider",
    provider = "columns",
    name = "WHERE LIKE pattern columns (string types)",
    input = "SELECT * FROM Employees WHERE FirstName LIKE |",
    cursor = { line = 1, col = 46 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      left_side = { column_name = "FirstName", table_ref = nil, data_type = "varchar" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "LastName", "Email" },  -- VARCHAR columns
        excludes = { "EmployeeID", "HireDate" },
      },
      type_compatibility = {
        preferred_type = "varchar",
        compatible_types = { "varchar", "nvarchar", "char", "nchar", "text", "ntext" },
      },
    },
  },

  {
    id = 3109,
    type = "provider",
    provider = "columns",
    name = "WHERE IS NULL columns",
    input = "SELECT * FROM Employees WHERE | IS NULL",
    cursor = { line = 1, col = 31 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "Email", "ManagerID" },  -- Nullable columns
      },
      metadata = {
        nullable_only = true,
      },
    },
  },

  {
    id = 3110,
    type = "provider",
    provider = "columns",
    name = "WHERE comparison operators (>, <, >=, <=)",
    input = "SELECT * FROM Employees WHERE Salary > |",
    cursor = { line = 1, col = 40 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      left_side = { column_name = "Salary", table_ref = nil, data_type = "decimal" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "Salary", "Bonus", "Commission" },  -- DECIMAL/MONEY columns
        excludes = { "FirstName", "EmployeeID" },
      },
      type_compatibility = {
        preferred_type = "decimal",
        compatible_types = { "decimal", "numeric", "money", "smallmoney", "float", "real" },
      },
    },
  },

  {
    id = 3111,
    type = "provider",
    provider = "columns",
    name = "WHERE with function (UPPER(|))",
    input = "SELECT * FROM Employees WHERE UPPER(|) = 'JOHN'",
    cursor = { line = 1, col = 37 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      in_function = "UPPER",
    },
    expected = {
      type = "column",
      items = {
        includes = { "FirstName", "LastName", "Email" },  -- String columns for UPPER
        excludes = { "EmployeeID", "HireDate" },
      },
    },
  },

  {
    id = 3112,
    type = "provider",
    provider = "columns",
    name = "WHERE with CAST",
    input = "SELECT * FROM Employees WHERE CAST(| AS VARCHAR)",
    cursor = { line = 1, col = 36 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      in_function = "CAST",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "HireDate", "DepartmentID" },  -- All columns can be CAST
      },
    },
  },

  {
    id = 3113,
    type = "provider",
    provider = "columns",
    name = "WHERE date comparison",
    input = "SELECT * FROM Employees WHERE HireDate >= '2020-01-01' AND HireDate <= |",
    cursor = { line = 1, col = 72 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      left_side = { column_name = "HireDate", table_ref = nil, data_type = "date" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "HireDate" },  -- DATE columns
        excludes = { "EmployeeID", "FirstName" },
      },
    },
  },

  {
    id = 3114,
    type = "provider",
    provider = "columns",
    name = "WHERE numeric comparison",
    input = "SELECT * FROM Products WHERE Price * Quantity > |",
    cursor = { line = 1, col = 49 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Products", alias = nil, schema = "dbo" } },
      left_side = { column_name = "Price", table_ref = nil, data_type = "decimal" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "Price", "Quantity", "Discount", "Tax" },  -- Numeric columns
        excludes = { "ProductName", "ProductID" },
      },
    },
  },

  {
    id = 3115,
    type = "provider",
    provider = "columns",
    name = "WHERE with parameter (@Param =)",
    input = "SELECT * FROM Employees WHERE EmployeeID = @EmpID AND DepartmentID = |",
    cursor = { line = 1, col = 70 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      left_side = { column_name = "DepartmentID", table_ref = nil, data_type = "int" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "ManagerID" },  -- INT columns
        excludes = { "FirstName", "HireDate" },
      },
    },
  },

  {
    id = 3116,
    type = "provider",
    provider = "columns",
    name = "WHERE multiple tables scope",
    input = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID WHERE |",
    cursor = { line = 1, col = 88 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "DepartmentID", "DepartmentName" },  -- Columns from both tables
      },
    },
  },

  {
    id = 3117,
    type = "provider",
    provider = "columns",
    name = "WHERE subquery correlation",
    input = "SELECT * FROM Employees e WHERE Salary > (SELECT AVG(Salary) FROM Employees WHERE DepartmentID = |)",
    cursor = { line = 1, col = 99 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Employees", alias = nil, schema = "dbo" },
      },
      left_side = { column_name = "DepartmentID", table_ref = nil, data_type = "int" },
      in_subquery = true,
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "EmployeeID", "ManagerID" },  -- INT columns from Employees
        excludes = { "FirstName", "HireDate" },
      },
    },
  },

  {
    id = 3118,
    type = "provider",
    provider = "columns",
    name = "WHERE with CASE expression",
    input = "SELECT * FROM Employees WHERE CASE WHEN | THEN 1 ELSE 0 END = 1",
    cursor = { line = 1, col = 41 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      in_case_when = true,
    },
    expected = {
      type = "column",
      items = {
        includes = { "IsActive", "EmployeeID", "DepartmentID", "HireDate" },  -- All columns for CASE WHEN
      },
    },
  },

  {
    id = 3119,
    type = "provider",
    provider = "columns",
    name = "WHERE column from CTE",
    input = "WITH DeptCTE AS (SELECT DepartmentID, DepartmentName FROM Departments) SELECT * FROM Employees e WHERE e.DepartmentID = (SELECT DepartmentID FROM DeptCTE WHERE |)",
    cursor = { line = 1, col = 168 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "DeptCTE", alias = nil, schema = nil, object_type = "cte" } },
      cte_columns = { "DepartmentID", "DepartmentName" },
      in_subquery = true,
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "DepartmentName" },  -- CTE columns only
        excludes = { "Location", "EmployeeID" },
      },
    },
  },

  {
    id = 3120,
    type = "provider",
    provider = "columns",
    name = "WHERE with NULL comparison hint",
    input = "SELECT * FROM Employees WHERE MiddleName IS NOT NULL AND | IS NOT NULL",
    cursor = { line = 1, col = 57 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "Email", "ManagerID" },  -- Nullable columns
      },
      metadata = {
        nullable_only = true,
      },
    },
  },

  -- =========================================================================
  -- ON Clause Columns with Fuzzy Matching (3121-3145)
  -- =========================================================================

  {
    id = 3121,
    type = "provider",
    provider = "columns",
    name = "Basic ON clause completion",
    input = "SELECT * FROM Employees e JOIN Departments d ON |",
    cursor = { line = 1, col = 49 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Departments", alias = "d" },
      },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "EmployeeID", "DepartmentName" },  -- All columns from both tables
      },
    },
  },

  {
    id = 3122,
    type = "provider",
    provider = "columns",
    name = "ON clause fuzzy match exact (EmployeeID = EmployeeID ★)",
    input = "SELECT * FROM Employees e JOIN Orders o ON e.EmployeeID = |",
    cursor = { line = 1, col = 59 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Orders", alias = "o", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Orders", alias = "o" },
      },
      left_side = { column_name = "EmployeeID", table_ref = "e", data_type = "int" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID" },  -- Exact match, highest priority
        priority_order = { "EmployeeID", "OrderID", "CustomerID" },
      },
      fuzzy_match = {
        target = "EmployeeID",
        best_match = "EmployeeID",
        score = 100,
      },
    },
  },

  {
    id = 3123,
    type = "provider",
    provider = "columns",
    name = "ON clause with hr.Benefits (cross-schema join)",
    input = "SELECT * FROM Employees e JOIN hr.Benefits b ON e.EmployeeID = |",
    cursor = { line = 1, col = 64 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Benefits", alias = "b", schema = "hr" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Benefits", alias = "b" },
      },
      left_side = { column_name = "EmployeeID", table_ref = "e", data_type = "int" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "BenefitID" },  -- Benefits columns with EmployeeID match
      },
    },
  },

  {
    id = 3124,
    type = "provider",
    provider = "columns",
    name = "ON clause with Projects table",
    input = "SELECT * FROM Departments d JOIN Projects p ON d.Budget = |",
    cursor = { line = 1, col = 59 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Departments", alias = "d", schema = "dbo" },
        { name = "Projects", alias = "p", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Departments", alias = "d" },
        right_table = { name = "Projects", alias = "p" },
      },
      left_side = { column_name = "Budget", table_ref = "d", data_type = "decimal(12,2)" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "Budget", "ProjectID" },  -- Projects columns with Budget match
      },
    },
  },

  {
    id = 3125,
    type = "provider",
    provider = "columns",
    name = "ON clause excludes left-side table",
    input = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = |",
    cursor = { line = 1, col = 65 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Departments", alias = "d" },
      },
      left_side = { column_name = "DepartmentID", table_ref = "e", data_type = "int" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "DepartmentName", "Location" },  -- Only Departments columns
        excludes = { "EmployeeID", "FirstName" },  -- Exclude Employees columns
      },
      table_filter = {
        only_from = "Departments",
      },
    },
  },

  {
    id = 3126,
    type = "provider",
    provider = "columns",
    name = "ON clause type compatible columns first",
    input = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = |",
    cursor = { line = 1, col = 65 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Departments", alias = "d" },
      },
      left_side = { column_name = "DepartmentID", table_ref = "e", data_type = "int" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID" },  -- INT column prioritized
        excludes = { "DepartmentName", "Location" },  -- VARCHAR columns de-prioritized
      },
      type_compatibility = {
        preferred_type = "int",
        compatible_types = { "int", "bigint", "smallint", "tinyint" },
      },
    },
  },

  {
    id = 3127,
    type = "provider",
    provider = "columns",
    name = "ON clause type warning INT vs VARCHAR",
    skip = true,  -- Type warning feature not yet implemented
    input = "SELECT * FROM Employees e JOIN Departments d ON e.EmployeeID = d.DepartmentName",
    cursor = { line = 1, col = 80 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Departments", alias = "d" },
      },
      left_side = { column_name = "EmployeeID", table_ref = "e", data_type = "int" },
      right_side = { column_name = "DepartmentName", table_ref = "d", data_type = "varchar" },
    },
    expected = {
      type = "warning",
      message = "Type mismatch in JOIN: EmployeeID (int) compared with DepartmentName (varchar)",
      severity = "warning",
    },
  },

  {
    id = 3128,
    type = "provider",
    provider = "columns",
    name = "ON clause type warning DATE vs INT",
    skip = true,  -- Type warning feature not yet implemented
    input = "SELECT * FROM Employees e JOIN Orders o ON e.HireDate = o.Id",
    cursor = { line = 1, col = 60 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Orders", alias = "o", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Orders", alias = "o" },
      },
      left_side = { column_name = "HireDate", table_ref = "e", data_type = "date" },
      right_side = { column_name = "Id", table_ref = "o", data_type = "int" },
    },
    expected = {
      type = "warning",
      message = "Type mismatch in JOIN: HireDate (date) compared with Id (int)",
      severity = "warning",
    },
  },

  {
    id = 3129,
    type = "provider",
    provider = "columns",
    name = "ON clause with FK column prioritization",
    input = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = |",
    cursor = { line = 1, col = 65 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Departments", alias = "d" },
      },
      left_side = { column_name = "DepartmentID", table_ref = "e", data_type = "int", is_fk = true },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID" },  -- FK target column prioritized
      },
      metadata = {
        fk_hint = {
          fk_column = "DepartmentID",
          referenced_table = "Departments",
          referenced_column = "DepartmentID",
        },
      },
    },
  },

  {
    id = 3130,
    type = "provider",
    provider = "columns",
    name = "ON clause multiple JOINs (third table)",
    input = "SELECT * FROM Employees e JOIN Orders o ON e.EmployeeID = o.EmployeeId JOIN Customers c ON o.CustomerId = |",
    cursor = { line = 1, col = 108 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Orders", alias = "o", schema = "dbo" },
        { name = "Customers", alias = "c", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Orders", alias = "o" },
        right_table = { name = "Customers", alias = "c" },
      },
      left_side = { column_name = "CustomerId", table_ref = "o", data_type = "int" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "Id", "CustomerId", "Name" },  -- Only Customers columns
        excludes = { "EmployeeID", "OrderId" },  -- Exclude previous tables
      },
    },
  },

  {
    id = 3131,
    type = "provider",
    provider = "columns",
    name = "ON clause self-join columns",
    input = "SELECT * FROM Employees e1 JOIN Employees e2 ON e1.ManagerID = |",
    cursor = { line = 1, col = 63 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e1", schema = "dbo" },
        { name = "Employees", alias = "e2", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e1" },
        right_table = { name = "Employees", alias = "e2" },
      },
      left_side = { column_name = "ManagerID", table_ref = "e1", data_type = "int" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID" },  -- Self-reference to PK
        priority_order = { "EmployeeID", "ManagerID" },
      },
    },
  },

  {
    id = 3132,
    type = "provider",
    provider = "columns",
    name = "ON clause with aliases (e.DeptID = d.|)",
    input = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.|",
    cursor = { line = 1, col = 67 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Departments", alias = "d" },
      },
      left_side = { column_name = "DepartmentID", table_ref = "e", data_type = "int" },
      table_ref = "d",
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "DepartmentName", "Location" },  -- Only d.* columns
        excludes = { "EmployeeID", "FirstName" },
      },
    },
  },

  {
    id = 3133,
    type = "provider",
    provider = "columns",
    name = "ON clause qualified suggestion (d.DepartmentID)",
    input = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = |",
    cursor = { line = 1, col = 65 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Departments", alias = "d" },
      },
      left_side = { column_name = "DepartmentID", table_ref = "e", data_type = "int" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID" },
      },
      metadata = {
        suggest_qualified = "d.DepartmentID",  -- Suggest with alias prefix
      },
    },
  },

  {
    id = 3134,
    type = "provider",
    provider = "columns",
    name = "ON clause after AND (additional condition)",
    input = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID AND |",
    cursor = { line = 1, col = 85 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Departments", alias = "d" },
      },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "DepartmentID", "DepartmentName" },  -- All columns from both tables
      },
    },
  },

  {
    id = 3135,
    type = "provider",
    provider = "columns",
    name = "ON clause with OR condition",
    input = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID OR |",
    cursor = { line = 1, col = 84 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Departments", alias = "d" },
      },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "DepartmentID", "DepartmentName" },
      },
    },
  },

  {
    id = 3136,
    type = "provider",
    provider = "columns",
    name = "ON clause complex expression",
    input = "SELECT * FROM Employees e JOIN Departments d ON UPPER(e.DepartmentCode) = UPPER(|)",
    cursor = { line = 1, col = 81 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Departments", alias = "d" },
      },
      left_side = { column_name = "DepartmentCode", table_ref = "e", data_type = "varchar" },
      in_function = "UPPER",
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentCode", "DepartmentName" },  -- String columns from d
        excludes = { "DepartmentID", "EmployeeID" },
      },
    },
  },

  {
    id = 3137,
    type = "provider",
    provider = "columns",
    name = "ON clause with function",
    input = "SELECT * FROM Employees e JOIN Departments d ON YEAR(e.HireDate) = |",
    cursor = { line = 1, col = 68 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Departments", alias = "d" },
      },
      left_side = { column_name = "HireDate", table_ref = "e", data_type = "date", in_function = "YEAR" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "EstablishedYear" },  -- INT columns (YEAR returns INT)
        excludes = { "DepartmentName" },
      },
    },
  },

  {
    id = 3138,
    type = "provider",
    provider = "columns",
    name = "ON clause CROSS JOIN (no columns)",
    input = "SELECT * FROM Employees e CROSS JOIN Departments d WHERE |",
    cursor = { line = 1, col = 58 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_type = "cross",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "DepartmentID", "DepartmentName" },  -- All columns (CROSS JOIN has no ON)
      },
    },
  },

  {
    id = 3139,
    type = "provider",
    provider = "columns",
    name = "ON clause LEFT JOIN columns",
    input = "SELECT * FROM Employees e LEFT JOIN Departments d ON e.DepartmentID = |",
    cursor = { line = 1, col = 71 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Departments", alias = "d" },
        join_type = "left",
      },
      left_side = { column_name = "DepartmentID", table_ref = "e", data_type = "int" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID" },  -- Departments columns
        excludes = { "EmployeeID", "FirstName" },
      },
    },
  },

  {
    id = 3140,
    type = "provider",
    provider = "columns",
    name = "ON clause RIGHT JOIN columns",
    input = "SELECT * FROM Employees e RIGHT JOIN Departments d ON e.DepartmentID = |",
    cursor = { line = 1, col = 72 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Departments", alias = "d" },
        join_type = "right",
      },
      left_side = { column_name = "DepartmentID", table_ref = "e", data_type = "int" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID" },
        excludes = { "EmployeeID", "FirstName" },
      },
    },
  },

  {
    id = 3141,
    type = "provider",
    provider = "columns",
    name = "ON clause FULL OUTER JOIN",
    input = "SELECT * FROM Employees e FULL OUTER JOIN Departments d ON e.DepartmentID = |",
    cursor = { line = 1, col = 77 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Departments", alias = "d" },
        join_type = "full",
      },
      left_side = { column_name = "DepartmentID", table_ref = "e", data_type = "int" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID" },
        excludes = { "EmployeeID", "FirstName" },
      },
    },
  },

  {
    id = 3142,
    type = "provider",
    provider = "columns",
    name = "ON clause derived table columns",
    input = "SELECT * FROM Employees e JOIN (SELECT DepartmentID, COUNT(*) AS EmpCount FROM Employees GROUP BY DepartmentID) sub ON e.DepartmentID = |",
    cursor = { line = 1, col = 136 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "sub", alias = "sub", schema = nil, object_type = "subquery" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "sub", alias = "sub" },
      },
      left_side = { column_name = "DepartmentID", table_ref = "e", data_type = "int" },
      subquery_columns = { "DepartmentID", "EmpCount" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "EmpCount" },  -- Subquery columns only
        excludes = { "EmployeeID", "FirstName" },
      },
    },
  },

  {
    id = 3143,
    type = "provider",
    provider = "columns",
    name = "ON clause CTE reference",
    input = "WITH DeptCTE AS (SELECT DepartmentID, DepartmentName FROM Departments) SELECT * FROM Employees e JOIN DeptCTE cte ON e.DepartmentID = |",
    cursor = { line = 1, col = 136 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "DeptCTE", alias = "cte", schema = nil, object_type = "cte" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "DeptCTE", alias = "cte" },
      },
      left_side = { column_name = "DepartmentID", table_ref = "e", data_type = "int" },
      cte_columns = { "DepartmentID", "DepartmentName" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "DepartmentName" },  -- CTE columns only
        excludes = { "Location", "EmployeeID" },
      },
    },
  },

  {
    id = 3144,
    type = "provider",
    provider = "columns",
    name = "ON clause with bracketed identifiers",
    input = "SELECT * FROM [Employees] e JOIN [Departments] d ON e.[DepartmentID] = |",
    cursor = { line = 1, col = 71 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Departments", alias = "d" },
      },
      left_side = { column_name = "DepartmentID", table_ref = "e", data_type = "int" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID" },
        excludes = { "EmployeeID", "FirstName" },
      },
    },
  },

  {
    id = 3145,
    type = "provider",
    provider = "columns",
    name = "ON clause case-insensitive fuzzy",
    input = "SELECT * FROM Employees e JOIN Departments d ON e.DEPARTMENTID = |",
    cursor = { line = 1, col = 65 },
    context = {
      mode = "on",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
      join_context = {
        left_table = { name = "Employees", alias = "e" },
        right_table = { name = "Departments", alias = "d" },
      },
      left_side = { column_name = "DEPARTMENTID", table_ref = "e", data_type = "int" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID" },  -- Case-insensitive match
      },
      fuzzy_match = {
        target = "DEPARTMENTID",
        best_match = "DepartmentID",
        score = 100,
      },
    },
  },

  -- =========================================================================
  -- ORDER BY / GROUP BY Columns (3146-3150)
  -- =========================================================================

  {
    id = 3146,
    type = "provider",
    provider = "columns",
    name = "Basic ORDER BY completion",
    input = "SELECT * FROM Employees ORDER BY |",
    cursor = { line = 1, col = 34 },
    context = {
      mode = "order_by",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName", "HireDate" },
      },
    },
  },

  {
    id = 3147,
    type = "provider",
    provider = "columns",
    name = "ORDER BY with alias prefix (e.|)",
    input = "SELECT * FROM Employees e ORDER BY e.|",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "order_by",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = "e", schema = "dbo" } },
      table_ref = "e",
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName", "HireDate" },
      },
    },
  },

  {
    id = 3148,
    type = "provider",
    provider = "columns",
    name = "ORDER BY after existing column",
    input = "SELECT * FROM Employees ORDER BY FirstName, |",
    cursor = { line = 1, col = 45 },
    context = {
      mode = "order_by",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "LastName", "EmployeeID", "HireDate" },
        excludes = { "FirstName" },  -- Already used in ORDER BY
      },
    },
  },

  {
    id = 3149,
    type = "provider",
    provider = "columns",
    name = "GROUP BY column completion",
    input = "SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY |",
    cursor = { line = 1, col = 55 },
    context = {
      mode = "group_by",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "EmployeeID", "HireDate" },  -- Non-aggregated columns
      },
    },
  },

  {
    id = 3150,
    type = "provider",
    provider = "columns",
    name = "GROUP BY with alias",
    input = "SELECT e.DepartmentID, COUNT(*) FROM Employees e GROUP BY e.|",
    cursor = { line = 1, col = 61 },
    context = {
      mode = "group_by",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = "e", schema = "dbo" } },
      table_ref = "e",
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "EmployeeID", "HireDate" },
      },
    },
  },

  -- =========================================================================
  -- ORDER BY / GROUP BY Columns Continued (3151-3160)
  -- =========================================================================

  {
    id = 3151,
    type = "provider",
    provider = "columns",
    name = "ORDER BY ASC/DESC context",
    input = "SELECT * FROM Employees ORDER BY FirstName ASC, |",
    cursor = { line = 1, col = 49 },
    context = {
      mode = "order_by",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "LastName", "EmployeeID", "HireDate" },
        excludes = { "FirstName" },
      },
    },
  },

  {
    id = 3152,
    type = "provider",
    provider = "columns",
    name = "ORDER BY with column index (1, 2)",
    input = "SELECT FirstName, LastName FROM Employees ORDER BY 1, |",
    cursor = { line = 1, col = 54 },
    context = {
      mode = "order_by",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      select_columns = { "FirstName", "LastName" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "FirstName", "LastName" },  -- Can reference selected columns by number or name
      },
    },
  },

  {
    id = 3153,
    type = "provider",
    provider = "columns",
    name = "ORDER BY expression column",
    input = "SELECT FirstName + ' ' + LastName AS FullName FROM Employees ORDER BY |",
    cursor = { line = 1, col = 70 },
    context = {
      mode = "order_by",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      select_aliases = { "FullName" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "FirstName", "LastName", "EmployeeID" },  -- Base columns (alias completion not yet implemented)
      },
    },
  },

  {
    id = 3154,
    type = "provider",
    provider = "columns",
    name = "GROUP BY multiple columns",
    input = "SELECT DepartmentID, HireDate, COUNT(*) FROM Employees GROUP BY DepartmentID, |",
    cursor = { line = 1, col = 79 },
    context = {
      mode = "group_by",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      already_grouped = { "DepartmentID" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "HireDate", "EmployeeID" },
        excludes = { "DepartmentID" },  -- Already in GROUP BY
      },
    },
  },

  {
    id = 3155,
    type = "provider",
    provider = "columns",
    name = "GROUP BY with HAVING clause",
    input = "SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY DepartmentID HAVING |",
    cursor = { line = 1, col = 75 },
    context = {
      mode = "having",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      grouped_columns = { "DepartmentID" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID" },  -- Grouped columns and aggregates
      },
      metadata = {
        suggest_aggregates = true,
      },
    },
  },

  {
    id = 3156,
    type = "provider",
    provider = "columns",
    name = "HAVING aggregate column",
    input = "SELECT DepartmentID, COUNT(*) AS EmpCount FROM Employees GROUP BY DepartmentID HAVING COUNT(*) > |",
    cursor = { line = 1, col = 95 },
    context = {
      mode = "having",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      grouped_columns = { "DepartmentID" },
    },
    expected = {
      type = "literal",
      items = {
        includes = { "5", "10", "20" },  -- Suggest numeric literals
      },
    },
  },

  {
    id = 3157,
    type = "provider",
    provider = "columns",
    name = "HAVING with comparison",
    input = "SELECT DepartmentID, AVG(Salary) FROM Employees GROUP BY DepartmentID HAVING AVG(Salary) > 50000 AND |",
    cursor = { line = 1, col = 100 },
    context = {
      mode = "having",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      grouped_columns = { "DepartmentID" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID" },
      },
      metadata = {
        suggest_aggregates = true,
      },
    },
  },

  {
    id = 3158,
    type = "provider",
    provider = "columns",
    name = "GROUP BY ROLLUP columns",
    input = "SELECT DepartmentID, HireDate, COUNT(*) FROM Employees GROUP BY ROLLUP(|)",
    cursor = { line = 1, col = 71 },
    context = {
      mode = "group_by",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      in_rollup = true,
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "HireDate", "EmployeeID" },
      },
    },
  },

  {
    id = 3159,
    type = "provider",
    provider = "columns",
    name = "GROUP BY CUBE columns",
    input = "SELECT DepartmentID, HireDate, COUNT(*) FROM Employees GROUP BY CUBE(|)",
    cursor = { line = 1, col = 69 },
    context = {
      mode = "group_by",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      in_cube = true,
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "HireDate", "EmployeeID" },
      },
    },
  },

  {
    id = 3160,
    type = "provider",
    provider = "columns",
    name = "ORDER BY in subquery",
    input = "SELECT * FROM (SELECT EmployeeID, FirstName FROM Employees ORDER BY |) sub",
    cursor = { line = 1, col = 66 },
    context = {
      mode = "order_by",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      in_subquery = true,
      select_columns = { "EmployeeID", "FirstName" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName" },  -- Can order by selected columns
      },
    },
  },

  -- =========================================================================
  -- INSERT Column List (3161-3175)
  -- =========================================================================

  {
    id = 3161,
    type = "provider",
    provider = "columns",
    name = "Basic INSERT INTO table (| completion",
    input = "INSERT INTO Employees (|)",
    cursor = { line = 1, col = 24 },
    context = {
      mode = "insert_columns",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = {} },
    },
    expected = {
      type = "column",
      items = {
        includes = { "FirstName", "LastName", "DepartmentID", "HireDate" },
        excludes = { "EmployeeID" },  -- IDENTITY column typically excluded
      },
    },
  },

  {
    id = 3162,
    type = "provider",
    provider = "columns",
    name = "INSERT with partial prefix",
    input = "INSERT INTO Employees (First|)",
    cursor = { line = 1, col = 29 },
    context = {
      mode = "insert_columns",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = {} },
      prefix = "First",
    },
    expected = {
      type = "column",
      items = {
        includes = { "FirstName" },
        excludes = { "LastName", "EmployeeID" },
      },
    },
  },

  {
    id = 3163,
    type = "provider",
    provider = "columns",
    name = "INSERT identity column marked [IDENTITY]",
    input = "INSERT INTO Employees (|)",
    cursor = { line = 1, col = 24 },
    context = {
      mode = "insert_columns",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = {} },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID" },  -- Include but mark as IDENTITY
      },
      metadata = {
        identity_columns = { "EmployeeID" },
      },
    },
  },

  {
    id = 3164,
    type = "provider",
    provider = "columns",
    name = "INSERT computed column marked [COMPUTED]",
    skip = true,  -- Computed columns not in mock database
    input = "INSERT INTO Employees (|)",
    cursor = { line = 1, col = 24 },
    context = {
      mode = "insert_columns",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = {} },
    },
    expected = {
      type = "column",
      items = {
        includes = { "FullName" },  -- Computed column
      },
      metadata = {
        computed_columns = { "FullName" },
      },
    },
  },

  {
    id = 3165,
    type = "provider",
    provider = "columns",
    name = "INSERT nullable column indication",
    input = "INSERT INTO Employees (|)",
    cursor = { line = 1, col = 24 },
    context = {
      mode = "insert_columns",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = {} },
    },
    expected = {
      type = "column",
      items = {
        includes = { "Email", "ManagerID" },  -- Nullable columns
      },
      metadata = {
        nullable_indicator = true,
      },
    },
  },

  {
    id = 3166,
    type = "provider",
    provider = "columns",
    name = "INSERT after existing columns (col1, |)",
    input = "INSERT INTO Employees (FirstName, |)",
    cursor = { line = 1, col = 35 },
    context = {
      mode = "insert_columns",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = { "FirstName" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "LastName", "DepartmentID", "HireDate" },
        excludes = { "FirstName" },  -- Already listed
      },
    },
  },

  {
    id = 3167,
    type = "provider",
    provider = "columns",
    name = "INSERT exclude already listed columns",
    input = "INSERT INTO Employees (FirstName, LastName, |)",
    cursor = { line = 1, col = 45 },
    context = {
      mode = "insert_columns",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = { "FirstName", "LastName" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "HireDate", "Email" },
        excludes = { "FirstName", "LastName" },
      },
    },
  },

  {
    id = 3168,
    type = "provider",
    provider = "columns",
    name = "INSERT with schema-qualified table",
    input = "INSERT INTO dbo.Employees (|)",
    cursor = { line = 1, col = 28 },
    context = {
      mode = "insert_columns",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees", schema = "dbo" } }, insert_columns = {} },
    },
    expected = {
      type = "column",
      items = {
        includes = { "FirstName", "LastName", "DepartmentID" },
      },
    },
  },

  {
    id = 3169,
    type = "provider",
    provider = "columns",
    name = "INSERT all columns suggestion",
    input = "INSERT INTO Employees (|)",
    cursor = { line = 1, col = 24 },
    context = {
      mode = "insert_columns",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = {} },
    },
    expected = {
      type = "column",
      items = {
        includes = { "FirstName", "LastName", "DepartmentID", "HireDate", "Email" },
      },
      metadata = {
        suggest_all_columns = true,
      },
    },
  },

  {
    id = 3170,
    type = "provider",
    provider = "columns",
    name = "INSERT primary key column",
    input = "INSERT INTO Employees (|)",
    cursor = { line = 1, col = 24 },
    context = {
      mode = "insert_columns",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = {} },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID" },  -- Primary key
      },
      metadata = {
        primary_key_columns = { "EmployeeID" },
      },
    },
  },

  {
    id = 3171,
    type = "provider",
    provider = "columns",
    name = "INSERT foreign key column",
    input = "INSERT INTO Employees (|)",
    cursor = { line = 1, col = 24 },
    context = {
      mode = "insert_columns",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = {} },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "ManagerID" },  -- Foreign keys
      },
      metadata = {
        foreign_key_columns = { "DepartmentID", "ManagerID" },
      },
    },
  },

  {
    id = 3172,
    type = "provider",
    provider = "columns",
    name = "INSERT DEFAULT value column",
    input = "INSERT INTO Employees (|)",
    cursor = { line = 1, col = 24 },
    context = {
      mode = "insert_columns",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = {} },
    },
    expected = {
      type = "column",
      items = {
        includes = { "IsActive", "CreatedDate" },  -- Columns with DEFAULT
      },
      metadata = {
        default_columns = { "IsActive", "CreatedDate" },
      },
    },
  },

  {
    id = 3173,
    type = "provider",
    provider = "columns",
    name = "INSERT column with CHECK constraint",
    input = "INSERT INTO Employees (|)",
    cursor = { line = 1, col = 24 },
    context = {
      mode = "insert_columns",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = {} },
    },
    expected = {
      type = "column",
      items = {
        includes = { "Salary", "Age" },  -- Columns with CHECK constraints
      },
      metadata = {
        check_constraint_columns = { "Salary", "Age" },
      },
    },
  },

  {
    id = 3174,
    type = "provider",
    provider = "columns",
    name = "INSERT column order by ordinal",
    input = "INSERT INTO Employees (|)",
    cursor = { line = 1, col = 24 },
    context = {
      mode = "insert_columns",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = {} },
    },
    expected = {
      type = "column",
      items = {
        priority_order = { "EmployeeID", "FirstName", "LastName", "Email", "DepartmentID" },  -- Ordered by ordinal_position
      },
    },
  },

  {
    id = 3175,
    type = "provider",
    provider = "columns",
    name = "INSERT from SELECT columns",
    input = "INSERT INTO Employees (FirstName, LastName) SELECT |",
    cursor = { line = 1, col = 52 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "vw_ActiveEmployees", alias = nil, schema = "dbo" } },
      insert_context = {
        target_table = "Employees",
        insert_columns = { "FirstName", "LastName" },
      },
    },
    expected = {
      type = "column",
      items = {
        includes = { "FirstName", "LastName" },  -- Prioritize matching columns from source
      },
    },
  },

  -- =========================================================================
  -- VALUES Clause Hints (3176-3190)
  -- =========================================================================

  {
    id = 3176,
    type = "provider",
    provider = "columns",
    name = "VALUES first position hint (column name + type)",
    skip = true,  -- VALUES hint feature not yet implemented
    input = "INSERT INTO Employees (FirstName, LastName) VALUES (|)",
    cursor = { line = 1, col = 52 },
    context = {
      mode = "values",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = { "FirstName", "LastName" } },
      value_position = 0,
    },
    expected = {
      type = "hint",
      message = "FirstName (VARCHAR(50))",
      metadata = {
        column_name = "FirstName",
        data_type = "varchar",
        max_length = 50,
      },
    },
  },

  {
    id = 3177,
    type = "provider",
    provider = "columns",
    name = "VALUES second position hint",
    skip = true,  -- VALUES hint feature not yet implemented
    input = "INSERT INTO Employees (FirstName, LastName) VALUES ('John', |)",
    cursor = { line = 1, col = 60 },
    context = {
      mode = "values",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = { "FirstName", "LastName" } },
      value_position = 1,
    },
    expected = {
      type = "hint",
      message = "LastName (VARCHAR(50))",
      metadata = {
        column_name = "LastName",
        data_type = "varchar",
        max_length = 50,
      },
    },
  },

  {
    id = 3178,
    type = "provider",
    provider = "columns",
    name = "VALUES third position hint",
    skip = true,  -- VALUES hint feature not yet implemented
    input = "INSERT INTO Employees (FirstName, LastName, DepartmentID) VALUES ('John', 'Doe', |)",
    cursor = { line = 1, col = 82 },
    context = {
      mode = "values",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = { "FirstName", "LastName", "DepartmentID" } },
      value_position = 2,
    },
    expected = {
      type = "hint",
      message = "DepartmentID (INT)",
      metadata = {
        column_name = "DepartmentID",
        data_type = "int",
      },
    },
  },

  {
    id = 3179,
    type = "provider",
    provider = "columns",
    name = "VALUES NULL suggestion for nullable",
    skip = true,  -- VALUES hint feature not yet implemented
    input = "INSERT INTO Employees (Email) VALUES (|)",
    cursor = { line = 1, col = 40 },
    context = {
      mode = "values",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = { "Email" } },
      value_position = 0,
    },
    expected = {
      type = "hint",
      message = "Email (NVARCHAR(100), nullable)",
      items = {
        includes = { "NULL" },
      },
      metadata = {
        column_name = "Email",
        data_type = "nvarchar",
        nullable = true,
      },
    },
  },

  {
    id = 3180,
    type = "provider",
    provider = "columns",
    name = "VALUES DEFAULT suggestion",
    input = "INSERT INTO Employees (IsActive) VALUES (|)",
    cursor = { line = 1, col = 41 },
    context = {
      mode = "values",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = { "IsActive" } },
      value_position = 0,
    },
    expected = {
      type = "hint",
      message = "IsActive (BIT, default: 1)",
      items = {
        includes = { "DEFAULT", "1", "0" },
      },
      metadata = {
        column_name = "IsActive",
        data_type = "bit",
        has_default = true,
      },
    },
  },

  {
    id = 3181,
    type = "provider",
    provider = "columns",
    name = "VALUES position beyond column count (no hint)",
    skip = true,  -- VALUES warning feature not implemented
    input = "INSERT INTO Employees (FirstName, LastName) VALUES ('John', 'Doe', |)",
    cursor = { line = 1, col = 67 },
    context = {
      mode = "values",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = { "FirstName", "LastName" } },
      value_position = 2,
    },
    expected = {
      type = "warning",
      message = "Too many values. Expected 2 columns, found 3",
      severity = "error",
    },
  },

  {
    id = 3182,
    type = "provider",
    provider = "columns",
    name = "VALUES with explicit column list",
    skip = true,  -- VALUES hint feature not implemented
    input = "INSERT INTO Employees (LastName, FirstName) VALUES (|)",
    cursor = { line = 1, col = 52 },
    context = {
      mode = "values",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = { "LastName", "FirstName" } },
      value_position = 0,
    },
    expected = {
      type = "hint",
      message = "LastName (VARCHAR(50))",  -- Follows column list order, not table order
      metadata = {
        column_name = "LastName",
        data_type = "varchar",
      },
    },
  },

  {
    id = 3183,
    type = "provider",
    provider = "columns",
    name = "VALUES identity column warning",
    skip = true,  -- VALUES hint feature not implemented
    input = "INSERT INTO Employees (EmployeeID, FirstName) VALUES (|)",
    cursor = { line = 1, col = 54 },
    context = {
      mode = "values",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = { "EmployeeID", "FirstName" } },
      value_position = 0,
    },
    expected = {
      type = "hint",
      message = "EmployeeID (INT, IDENTITY)",
      metadata = {
        column_name = "EmployeeID",
        data_type = "int",
        is_identity = true,
      },
    },
  },

  {
    id = 3184,
    type = "provider",
    provider = "columns",
    name = "VALUES computed column warning",
    skip = true,  -- Computed column warning feature not yet implemented
    input = "INSERT INTO Employees (FullName, FirstName) VALUES (|)",
    cursor = { line = 1, col = 52 },
    context = {
      mode = "values",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = { "FullName", "FirstName" } },
      value_position = 0,
    },
    expected = {
      type = "warning",
      message = "FullName is a computed column and cannot be inserted",
      severity = "error",
    },
  },

  {
    id = 3185,
    type = "provider",
    provider = "columns",
    name = "VALUES type hint (INT)",
    skip = true,  -- VALUES hint feature not implemented
    input = "INSERT INTO Employees (DepartmentID) VALUES (|)",
    cursor = { line = 1, col = 45 },
    context = {
      mode = "values",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = { "DepartmentID" } },
      value_position = 0,
    },
    expected = {
      type = "hint",
      message = "DepartmentID (INT)",
      metadata = {
        column_name = "DepartmentID",
        data_type = "int",
      },
    },
  },

  {
    id = 3186,
    type = "provider",
    provider = "columns",
    name = "VALUES type hint (VARCHAR)",
    skip = true,  -- VALUES hint feature not implemented
    input = "INSERT INTO Employees (FirstName) VALUES (|)",
    cursor = { line = 1, col = 42 },
    context = {
      mode = "values",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = { "FirstName" } },
      value_position = 0,
    },
    expected = {
      type = "hint",
      message = "FirstName (VARCHAR(50))",
      metadata = {
        column_name = "FirstName",
        data_type = "varchar",
        max_length = 50,
      },
    },
  },

  {
    id = 3187,
    type = "provider",
    provider = "columns",
    name = "VALUES type hint (DATE)",
    input = "INSERT INTO Employees (HireDate) VALUES (|)",
    cursor = { line = 1, col = 41 },
    context = {
      mode = "values",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = { "HireDate" } },
      value_position = 0,
    },
    expected = {
      type = "hint",
      message = "HireDate (DATE)",
      items = {
        includes = { "GETDATE()", "CAST('2024-01-01' AS DATE)" },
      },
      metadata = {
        column_name = "HireDate",
        data_type = "date",
      },
    },
  },

  {
    id = 3188,
    type = "provider",
    provider = "columns",
    name = "VALUES type hint (DECIMAL)",
    skip = true,  -- VALUES hint feature not implemented
    input = "INSERT INTO Products (Price) VALUES (|)",
    cursor = { line = 1, col = 37 },
    context = {
      mode = "values",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Products", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Products" } }, insert_columns = { "Price" } },
      value_position = 0,
    },
    expected = {
      type = "hint",
      message = "Price (DECIMAL(10,2))",
      metadata = {
        column_name = "Price",
        data_type = "decimal",
        precision = 10,
        scale = 2,
      },
    },
  },

  {
    id = 3189,
    type = "provider",
    provider = "columns",
    name = "VALUES multiple rows (second row)",
    skip = true,  -- VALUES hint feature not implemented
    input = "INSERT INTO Employees (FirstName, LastName) VALUES ('John', 'Doe'), (|)",
    cursor = { line = 1, col = 69 },
    context = {
      mode = "values",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
      chunk = { tables = { { name = "Employees" } }, insert_columns = { "FirstName", "LastName" } },
      value_position = 0,
      row_number = 2,
    },
    expected = {
      type = "hint",
      message = "FirstName (VARCHAR(50))",
      metadata = {
        column_name = "FirstName",
        data_type = "varchar",
      },
    },
  },

  {
    id = 3190,
    type = "provider",
    provider = "columns",
    name = "VALUES with SELECT subquery",
    input = "INSERT INTO Employees (DepartmentID) VALUES ((SELECT | FROM Departments))",
    cursor = { line = 1, col = 53 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Departments", alias = nil, schema = "dbo" } },
      in_subquery = true,
      values_context = {
        target_column = "DepartmentID",
        data_type = "int",
      },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID" },  -- Type-compatible columns prioritized
        excludes = { "DepartmentName", "Location" },
      },
    },
  },

  -- =========================================================================
  -- Edge Cases (3191-3200)
  -- =========================================================================

  {
    id = 3191,
    type = "provider",
    provider = "columns",
    name = "Unknown table returns no columns",
    input = "SELECT * FROM NonExistentTable WHERE |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "where",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "NonExistentTable", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = {},  -- No columns for non-existent table
      },
    },
  },

  {
    id = 3192,
    type = "provider",
    provider = "columns",
    name = "Column completion in SQL comment (no trigger)",
    input = "SELECT * FROM Employees WHERE -- |",
    cursor = { line = 1, col = 35 },
    context = {
      mode = "comment",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "none",  -- No completion in comments
    },
  },

  {
    id = 3193,
    type = "provider",
    provider = "columns",
    name = "Column completion in string literal (no trigger)",
    input = "SELECT * FROM Employees WHERE FirstName = '|'",
    cursor = { line = 1, col = 44 },
    context = {
      mode = "string_literal",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "none",  -- No completion in string literals
    },
  },

  {
    id = 3194,
    type = "provider",
    provider = "columns",
    name = "Very long column name (100+ chars)",
    input = "SELECT | FROM Employees",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "VeryLongColumnNameThatExceedsNormalLimitsButIsStillValidInDatabaseSystemsForSomeReasonAndShouldBeHandledProperly" },
      },
    },
  },

  {
    id = 3195,
    type = "provider",
    provider = "columns",
    name = "Special characters in column name",
    input = "SELECT | FROM Employees",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "Column$Name", "Column#Value", "Column@Reference" },  -- Special characters
      },
      metadata = {
        bracket_required = true,
      },
    },
  },

  {
    id = 3196,
    type = "provider",
    provider = "columns",
    name = "Column with reserved word name ([Order], [Select])",
    input = "SELECT | FROM Orders",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Orders", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "Order", "Select", "From" },  -- Reserved words
      },
      metadata = {
        bracket_required = true,
      },
    },
  },

  {
    id = 3197,
    type = "provider",
    provider = "columns",
    name = "Unicode column name",
    input = "SELECT | FROM Employees",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "名前", "Prénom", "Фамилия", "اسم" },  -- Unicode column names
      },
    },
  },

  {
    id = 3198,
    type = "provider",
    provider = "columns",
    name = "Column from cross-database reference",
    input = "SELECT | FROM OtherDB.dbo.Employees",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "Employees", alias = nil, schema = "dbo", database = "OtherDB" } },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName", "LastName" },  -- Columns from other database
      },
    },
  },

  {
    id = 3199,
    type = "provider",
    provider = "columns",
    name = "Derived table column completion",
    input = "SELECT | FROM (SELECT EmployeeID, FirstName FROM Employees) AS DerivedTable",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = { { name = "DerivedTable", alias = "DerivedTable", schema = nil, object_type = "subquery" } },
      subquery_columns = { "EmployeeID", "FirstName" },
    },
    expected = {
      type = "column",
      items = {
        includes = { "EmployeeID", "FirstName" },  -- Only derived table columns
        excludes = { "LastName", "DepartmentID" },
      },
    },
  },

  {
    id = 3200,
    type = "provider",
    provider = "columns",
    name = "Column deduplication across tables",
    input = "SELECT | FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      tables_in_scope = {
        { name = "Employees", alias = "e", schema = "dbo" },
        { name = "Departments", alias = "d", schema = "dbo" },
      },
    },
    expected = {
      type = "column",
      items = {
        includes = { "DepartmentID", "EmployeeID", "FirstName", "DepartmentName" },
      },
      metadata = {
        ambiguous_columns = { "DepartmentID" },  -- Column exists in both tables
        suggest_qualified = true,
      },
    },
  },
}
