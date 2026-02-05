-- Test file: left_side_extraction.lua
-- IDs: 3601-3650
-- Tests: Left-side column extraction for comparison expressions
--
-- Test categories:
-- - 3601-3615: Basic extraction (qualified, operators)
-- - 3616-3630: After logical operators (AND, OR)
-- - 3631-3650: Edge cases

return {
  -- Basic Extraction (3601-3615)
  {
    id = 3601,
    type = "context",
    subtype = "left_side",
    name = "Qualified column extraction (alias.column)",
    input = "WHERE e.EmployeeID = |",
    cursor = { line = 1, col = 22 },
    expected = {
      left_side = {
        qualified = "e.EmployeeID",
        table_ref = "e",
        column_name = "EmployeeID",
      },
    },
  },
  {
    id = 3602,
    type = "context",
    subtype = "left_side",
    name = "Unqualified column",
    input = "WHERE FirstName = |",
    cursor = { line = 1, col = 19 },
    expected = {
      left_side = {
        qualified = "FirstName",
        table_ref = nil,
        column_name = "FirstName",
      },
    },
  },
  {
    id = 3603,
    type = "context",
    subtype = "left_side",
    name = "Schema.table.column",
    input = "WHERE dbo.Employees.LastName = |",
    cursor = { line = 1, col = 32 },
    expected = {
      left_side = {
        qualified = "dbo.Employees.LastName",
        table_ref = "dbo.Employees",
        column_name = "LastName",
      },
    },
  },
  {
    id = 3604,
    type = "context",
    subtype = "left_side",
    name = "Database.schema.table.column",
    input = "WHERE TestDB.dbo.Users.UserID = |",
    cursor = { line = 1, col = 33 },
    expected = {
      left_side = {
        qualified = "TestDB.dbo.Users.UserID",
        table_ref = "TestDB.dbo.Users",
        column_name = "UserID",
      },
    },
  },
  {
    id = 3605,
    type = "context",
    subtype = "left_side",
    name = "Equals operator (=)",
    input = "WHERE Status = |",
    cursor = { line = 1, col = 16 },
    expected = {
      left_side = {
        qualified = "Status",
        table_ref = nil,
        column_name = "Status",
      },
    },
  },
  {
    id = 3606,
    type = "context",
    subtype = "left_side",
    name = "Not equals (<>)",
    input = "WHERE Type <> |",
    cursor = { line = 1, col = 15 },
    expected = {
      left_side = {
        qualified = "Type",
        table_ref = nil,
        column_name = "Type",
      },
    },
  },
  {
    id = 3607,
    type = "context",
    subtype = "left_side",
    name = "Greater than (>)",
    input = "WHERE Price > |",
    cursor = { line = 1, col = 15 },
    expected = {
      left_side = {
        qualified = "Price",
        table_ref = nil,
        column_name = "Price",
      },
    },
  },
  {
    id = 3608,
    type = "context",
    subtype = "left_side",
    name = "Less than (<)",
    input = "WHERE Quantity < |",
    cursor = { line = 1, col = 18 },
    expected = {
      left_side = {
        qualified = "Quantity",
        table_ref = nil,
        column_name = "Quantity",
      },
    },
  },
  {
    id = 3609,
    type = "context",
    subtype = "left_side",
    name = "Greater or equal (>=)",
    input = "WHERE Age >= |",
    cursor = { line = 1, col = 14 },
    expected = {
      left_side = {
        qualified = "Age",
        table_ref = nil,
        column_name = "Age",
      },
    },
  },
  {
    id = 3610,
    type = "context",
    subtype = "left_side",
    name = "Less or equal (<=)",
    input = "WHERE Score <= |",
    cursor = { line = 1, col = 16 },
    expected = {
      left_side = {
        qualified = "Score",
        table_ref = nil,
        column_name = "Score",
      },
    },
  },
  {
    id = 3611,
    type = "context",
    subtype = "left_side",
    name = "Not equal (!=)",
    input = "WHERE Level != |",
    cursor = { line = 1, col = 16 },
    expected = {
      left_side = {
        qualified = "Level",
        table_ref = nil,
        column_name = "Level",
      },
    },
  },
  {
    id = 3612,
    type = "context",
    subtype = "left_side",
    name = "With whitespace around operator",
    input = "WHERE   City   =   |",
    cursor = { line = 1, col = 20 },
    expected = {
      left_side = {
        qualified = "City",
        table_ref = nil,
        column_name = "City",
      },
    },
  },
  {
    id = 3613,
    type = "context",
    subtype = "left_side",
    name = "No whitespace around operator",
    input = "WHERE Country=|",
    cursor = { line = 1, col = 15 },
    expected = {
      left_side = {
        qualified = "Country",
        table_ref = nil,
        column_name = "Country",
      },
    },
  },
  {
    id = 3614,
    type = "context",
    subtype = "left_side",
    name = "Multiple dots in path",
    input = "WHERE db.schema.tbl.col = |",
    cursor = { line = 1, col = 27 },
    expected = {
      left_side = {
        qualified = "db.schema.tbl.col",
        table_ref = "db.schema.tbl",
        column_name = "col",
      },
    },
  },
  {
    id = 3615,
    type = "context",
    subtype = "left_side",
    name = "Bracketed identifier [col]",
    input = "WHERE t.[Order ID] = |",
    cursor = { line = 1, col = 22 },
    expected = {
      left_side = {
        qualified = "t.[Order ID]",
        table_ref = "t",
        column_name = "[Order ID]",
      },
    },
  },

  -- After Logical Operators (3616-3630)
  {
    id = 3616,
    type = "context",
    subtype = "left_side",
    name = "After AND",
    input = "WHERE Status = 1 AND Active = |",
    cursor = { line = 1, col = 31 },
    expected = {
      left_side = {
        qualified = "Active",
        table_ref = nil,
        column_name = "Active",
      },
    },
  },
  {
    id = 3617,
    type = "context",
    subtype = "left_side",
    name = "After OR",
    input = "WHERE Type = 'A' OR Category = |",
    cursor = { line = 1, col = 32 },
    expected = {
      left_side = {
        qualified = "Category",
        table_ref = nil,
        column_name = "Category",
      },
    },
  },
  {
    id = 3618,
    type = "context",
    subtype = "left_side",
    name = "After AND with qualified",
    input = "WHERE e.FirstName = 'John' AND e.LastName = |",
    cursor = { line = 1, col = 46 },
    expected = {
      left_side = {
        qualified = "e.LastName",
        table_ref = "e",
        column_name = "LastName",
      },
    },
  },
  {
    id = 3619,
    type = "context",
    subtype = "left_side",
    name = "After OR with qualified",
    input = "WHERE d.Type = 1 OR d.Status = |",
    cursor = { line = 1, col = 32 },
    expected = {
      left_side = {
        qualified = "d.Status",
        table_ref = "d",
        column_name = "Status",
      },
    },
  },
  {
    id = 3620,
    type = "context",
    subtype = "left_side",
    name = "Case-insensitive AND",
    input = "WHERE Flag = 0 and Level = |",
    cursor = { line = 1, col = 28 },
    expected = {
      left_side = {
        qualified = "Level",
        table_ref = nil,
        column_name = "Level",
      },
    },
  },
  {
    id = 3621,
    type = "context",
    subtype = "left_side",
    name = "Case-insensitive OR",
    input = "WHERE Code = 'X' or Name = |",
    cursor = { line = 1, col = 28 },
    expected = {
      left_side = {
        qualified = "Name",
        table_ref = nil,
        column_name = "Name",
      },
    },
  },
  {
    id = 3622,
    type = "context",
    subtype = "left_side",
    name = "Multiple AND conditions",
    input = "WHERE A = 1 AND B = 2 AND C = |",
    cursor = { line = 1, col = 31 },
    expected = {
      left_side = {
        qualified = "C",
        table_ref = nil,
        column_name = "C",
      },
    },
  },
  {
    id = 3623,
    type = "context",
    subtype = "left_side",
    name = "Multiple OR conditions",
    input = "WHERE X = 1 OR Y = 2 OR Z = |",
    cursor = { line = 1, col = 29 },
    expected = {
      left_side = {
        qualified = "Z",
        table_ref = nil,
        column_name = "Z",
      },
    },
  },
  {
    id = 3624,
    type = "context",
    subtype = "left_side",
    name = "Mixed AND/OR",
    input = "WHERE (A = 1 OR B = 2) AND C = |",
    cursor = { line = 1, col = 32 },
    expected = {
      left_side = {
        qualified = "C",
        table_ref = nil,
        column_name = "C",
      },
    },
  },
  {
    id = 3625,
    type = "context",
    subtype = "left_side",
    name = "AND with schema-qualified",
    input = "WHERE t.Col1 = 1 AND dbo.t.Col2 = |",
    cursor = { line = 1, col = 35 },
    expected = {
      left_side = {
        qualified = "dbo.t.Col2",
        table_ref = "dbo.t",
        column_name = "Col2",
      },
    },
  },
  {
    id = 3626,
    type = "context",
    subtype = "left_side",
    name = "OR with database-qualified",
    input = "WHERE Status = 1 OR DB.dbo.tbl.Active = |",
    cursor = { line = 1, col = 41 },
    expected = {
      left_side = {
        qualified = "DB.dbo.tbl.Active",
        table_ref = "DB.dbo.tbl",
        column_name = "Active",
      },
    },
  },
  {
    id = 3627,
    type = "context",
    subtype = "left_side",
    name = "Nested parentheses",
    input = "WHERE ((A = 1) AND (B = 2)) OR C = |",
    cursor = { line = 1, col = 36 },
    expected = {
      left_side = {
        qualified = "C",
        table_ref = nil,
        column_name = "C",
      },
    },
  },
  {
    id = 3628,
    type = "context",
    subtype = "left_side",
    name = "After NOT",
    input = "WHERE NOT Deleted = |",
    cursor = { line = 1, col = 21 },
    expected = {
      left_side = {
        qualified = "Deleted",
        table_ref = nil,
        column_name = "Deleted",
      },
    },
  },
  {
    id = 3629,
    type = "context",
    subtype = "left_side",
    name = "After AND NOT",
    input = "WHERE Active = 1 AND NOT Archived = |",
    cursor = { line = 1, col = 37 },
    expected = {
      left_side = {
        qualified = "Archived",
        table_ref = nil,
        column_name = "Archived",
      },
    },
  },
  {
    id = 3630,
    type = "context",
    subtype = "left_side",
    name = "Complex expression",
    input = "WHERE (e.Dept = 'IT' AND e.Level > 5) OR e.Manager = |",
    cursor = { line = 1, col = 54 },
    expected = {
      left_side = {
        qualified = "e.Manager",
        table_ref = "e",
        column_name = "Manager",
      },
    },
  },

  -- Edge Cases (3631-3650)
  {
    id = 3631,
    type = "context",
    subtype = "left_side",
    name = "No comparison operator (null result)",
    input = "WHERE EmployeeID|",
    cursor = { line = 1, col = 17 },
    expected = {
      left_side = nil,
    },
  },
  {
    id = 3632,
    type = "context",
    subtype = "left_side",
    name = "Incomplete expression",
    input = "WHERE Column = ",
    cursor = { line = 1, col = 15 },
    expected = {
      left_side = {
        qualified = "Column",
        table_ref = nil,
        column_name = "Column",
      },
    },
  },
  {
    id = 3633,
    type = "context",
    subtype = "left_side",
    name = "Function call left side",
    input = "WHERE UPPER(Name) = |",
    cursor = { line = 1, col = 21 },
    expected = {
      left_side = nil, -- Functions not extracted
    },
  },
  {
    id = 3634,
    type = "context",
    subtype = "left_side",
    name = "CASE expression left side",
    input = "WHERE CASE WHEN A = 1 THEN B END = |",
    cursor = { line = 1, col = 36 },
    expected = {
      left_side = nil, -- CASE expressions not extracted
    },
  },
  {
    id = 3635,
    type = "context",
    subtype = "left_side",
    name = "Arithmetic expression",
    input = "WHERE Price * Quantity = |",
    cursor = { line = 1, col = 26 },
    expected = {
      left_side = nil, -- Arithmetic not extracted
    },
  },
  {
    id = 3636,
    type = "context",
    subtype = "left_side",
    name = "String literal (no extraction)",
    input = "WHERE 'constant' = |",
    cursor = { line = 1, col = 20 },
    expected = {
      left_side = nil,
    },
  },
  {
    id = 3637,
    type = "context",
    subtype = "left_side",
    name = "Numeric literal (no extraction)",
    input = "WHERE 123 = |",
    cursor = { line = 1, col = 13 },
    expected = {
      left_side = nil,
    },
  },
  {
    id = 3638,
    type = "context",
    subtype = "left_side",
    name = "Parameter @param",
    input = "WHERE @ParamName = |",
    cursor = { line = 1, col = 20 },
    expected = {
      left_side = {
        qualified = "@ParamName",
        table_ref = nil,
        column_name = "@ParamName",
      },
    },
  },
  {
    id = 3639,
    type = "context",
    subtype = "left_side",
    name = "Column with underscore",
    input = "WHERE First_Name = |",
    cursor = { line = 1, col = 20 },
    expected = {
      left_side = {
        qualified = "First_Name",
        table_ref = nil,
        column_name = "First_Name",
      },
    },
  },
  {
    id = 3640,
    type = "context",
    subtype = "left_side",
    name = "Column with numbers",
    input = "WHERE Col123 = |",
    cursor = { line = 1, col = 16 },
    expected = {
      left_side = {
        qualified = "Col123",
        table_ref = nil,
        column_name = "Col123",
      },
    },
  },
  {
    id = 3641,
    type = "context",
    subtype = "left_side",
    name = "Column starting with @",
    input = "WHERE @@IDENTITY = |",
    cursor = { line = 1, col = 20 },
    expected = {
      left_side = {
        qualified = "@@IDENTITY",
        table_ref = nil,
        column_name = "@@IDENTITY",
      },
    },
  },
  {
    id = 3642,
    type = "context",
    subtype = "left_side",
    name = "Column starting with #",
    input = "WHERE #TempCol = |",
    cursor = { line = 1, col = 18 },
    expected = {
      left_side = {
        qualified = "#TempCol",
        table_ref = nil,
        column_name = "#TempCol",
      },
    },
  },
  {
    id = 3643,
    type = "context",
    subtype = "left_side",
    name = "Very long column name",
    input = "WHERE VeryLongColumnNameThatExceedsNormalLength = |",
    cursor = { line = 1, col = 51 },
    expected = {
      left_side = {
        qualified = "VeryLongColumnNameThatExceedsNormalLength",
        table_ref = nil,
        column_name = "VeryLongColumnNameThatExceedsNormalLength",
      },
    },
  },
  {
    id = 3644,
    type = "context",
    subtype = "left_side",
    name = "Special characters",
    input = "WHERE t.[Column-Name] = |",
    cursor = { line = 1, col = 25 },
    expected = {
      left_side = {
        qualified = "t.[Column-Name]",
        table_ref = "t",
        column_name = "[Column-Name]",
      },
    },
  },
  {
    id = 3645,
    type = "context",
    subtype = "left_side",
    name = "Unicode column name",
    input = "WHERE t.員工ID = |",
    cursor = { line = 1, col = 16 },
    expected = {
      left_side = {
        qualified = "t.員工ID",
        table_ref = "t",
        column_name = "員工ID",
      },
    },
  },
  {
    id = 3646,
    type = "context",
    subtype = "left_side",
    name = "IN clause (no left side after IN)",
    input = "WHERE Status IN (|",
    cursor = { line = 1, col = 18 },
    expected = {
      left_side = nil, -- IN clause, not a comparison
    },
  },
  {
    id = 3647,
    type = "context",
    subtype = "left_side",
    name = "BETWEEN clause",
    input = "WHERE Age BETWEEN 18 AND |",
    cursor = { line = 1, col = 26 },
    expected = {
      left_side = nil, -- BETWEEN has different structure
    },
  },
  {
    id = 3648,
    type = "context",
    subtype = "left_side",
    name = "LIKE clause",
    input = "WHERE Name LIKE |",
    cursor = { line = 1, col = 17 },
    expected = {
      left_side = {
        qualified = "Name",
        table_ref = nil,
        column_name = "Name",
      },
    },
  },
  {
    id = 3649,
    type = "context",
    subtype = "left_side",
    name = "IS NULL (no right side)",
    input = "WHERE DeletedDate IS NULL|",
    cursor = { line = 1, col = 26 },
    expected = {
      left_side = nil, -- IS NULL has no right side
    },
  },
  {
    id = 3650,
    type = "context",
    subtype = "left_side",
    name = "Multiple expressions on line",
    input = "WHERE A = 1 AND B = 2 AND C = |",
    cursor = { line = 1, col = 31 },
    expected = {
      left_side = {
        qualified = "C",
        table_ref = nil,
        column_name = "C",
      },
    },
  },
}
