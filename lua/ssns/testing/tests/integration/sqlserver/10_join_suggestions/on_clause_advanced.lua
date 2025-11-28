-- Integration Tests: JOIN Suggestions - ON Clause Advanced
-- Test IDs: 4351-4400
-- Tests advanced ON clause completion, type warnings, and fuzzy matching

return {
  -- ============================================================================
  -- 4351-4360: ON clause type warnings
  -- ============================================================================
  {
    number = 4351,
    description = "ON clause - type mismatch warning (int vs varchar)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.FirstName = d.DepartmentID]],
    cursor = { line = 0, col = 79 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
          "incompatible_types",
        },
      },
    },
  },
  {
    number = 4352,
    description = "ON clause - no warning for compatible types (int = int)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID]],
    cursor = { line = 0, col = 82 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4353,
    description = "ON clause - warning for date vs numeric",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Projects p ON e.HireDate = p.ProjectID]],
    cursor = { line = 0, col = 68 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
          "incompatible_types",
        },
      },
    },
  },
  {
    number = 4354,
    description = "ON clause - compatible varchar types",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.FirstName = d.DepartmentName]],
    cursor = { line = 0, col = 79 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4355,
    description = "ON clause - compatible numeric types (int vs bigint)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Orders o ON e.EmployeeID = o.Id]],
    cursor = { line = 0, col = 59 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4356,
    description = "ON clause - compatible date types",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Projects p ON e.HireDate = p.StartDate]],
    cursor = { line = 0, col = 68 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4357,
    description = "ON clause - warning for bit vs varchar",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.IsActive = d.DepartmentName]],
    cursor = { line = 0, col = 75 },
    expected = {
      type = "warning",
      items = {
        includes_any = {
          "type_mismatch",
          "incompatible_types",
        },
      },
    },
  },
  {
    number = 4358,
    description = "ON clause - compatible decimal types",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Projects p ON e.Salary = p.Budget]],
    cursor = { line = 0, col = 62 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4359,
    description = "ON clause - compatible int types",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Customers c ON e.EmployeeID = c.Id]],
    cursor = { line = 0, col = 64 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },
  {
    number = 4360,
    description = "ON clause - compatible nullable columns",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID]],
    cursor = { line = 0, col = 76 },
    expected = {
      type = "no_warning",
      valid = true,
    },
  },

  -- ============================================================================
  -- 4361-4370: Fuzzy column name matching in ON clause
  -- ============================================================================
  {
    number = 4361,
    description = "ON clause - fuzzy match with partial DepartmentID",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.]],
    cursor = { line = 0, col = 67 },
    expected = {
      type = "column",
      items = {
        -- Should prioritize DepartmentID due to exact match on left side
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4362,
    description = "ON clause - suggest EmployeeID based on context",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Orders o ON o.EmployeeId = e.]],
    cursor = { line = 0, col = 58 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4363,
    description = "ON clause - suggest Id based on CustomerId context",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN Customers c ON o.CustomerId = c.]],
    cursor = { line = 0, col = 59 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Id",
          "CustomerId",
        },
      },
    },
  },
  {
    number = 4364,
    description = "ON clause - suggest ProjectID from Projects table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Projects p ON e.EmployeeID = p.]],
    cursor = { line = 0, col = 60 },
    expected = {
      type = "column",
      items = {
        includes = {
          "ProjectID",
        },
      },
    },
  },
  {
    number = 4365,
    description = "ON clause - suggest matching DepartmentID",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.]],
    cursor = { line = 0, col = 67 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4366,
    description = "ON clause - suggest ManagerID from Departments",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.EmployeeID = d.]],
    cursor = { line = 0, col = 62 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "ManagerID",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4367,
    description = "ON clause - exact match preferred over fuzzy",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.]],
    cursor = { line = 0, col = 67 },
    expected = {
      type = "column",
      items = {
        -- DepartmentID should be first due to exact name match
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4368,
    description = "ON clause - fuzzy match with camelCase variation",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.departmentId = d.]],
    cursor = { line = 0, col = 67 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4369,
    description = "ON clause - suggest RegionID from Regions table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Countries c JOIN Regions r ON c.RegionID = r.]],
    cursor = { line = 0, col = 59 },
    expected = {
      type = "column",
      items = {
        includes = {
          "RegionID",
        },
      },
    },
  },
  {
    number = 4370,
    description = "ON clause - no fuzzy match for unrelated columns",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.FirstName = d.]],
    cursor = { line = 0, col = 64 },
    expected = {
      type = "column",
      items = {
        -- Should suggest string columns, not ID columns
        includes_any = {
          "DepartmentName",
        },
        excludes = {
          "DepartmentID",
        },
      },
    },
  },

  -- ============================================================================
  -- 4371-4380: Complex multi-table ON clauses
  -- ============================================================================
  {
    number = 4371,
    description = "ON clause - three table join, third table ON",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
JOIN Projects p ON ]],
    cursor = { line = 2, col = 18 },
    expected = {
      type = "column",
      items = {
        -- Should offer columns from all three tables
        includes_any = {
          "ProjectID",
          "DepartmentID",
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4372,
    description = "ON clause - four table join with alias",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
JOIN Projects p ON p.ProjectID = e.EmployeeID
JOIN Customers c ON c.]],
    cursor = { line = 4, col = 21 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Id",
          "CustomerId",
        },
      },
    },
  },
  {
    number = 4373,
    description = "ON clause - self-join with different aliases",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Departments d1
JOIN Departments d2 ON d1.ManagerID = d2.]],
    cursor = { line = 1, col = 41 },
    expected = {
      type = "column",
      items = {
        includes = {
          "ManagerID",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4374,
    description = "ON clause - hierarchical manager relationship",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
JOIN Employees mgr ON d.ManagerID = mgr.]],
    cursor = { line = 3, col = 40 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4375,
    description = "ON clause - mixed JOIN types",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees e
INNER JOIN Departments d ON e.DepartmentID = d.DepartmentID
LEFT JOIN Projects p ON p.ProjectID = e.EmployeeID
RIGHT JOIN Orders o ON o.]],
    cursor = { line = 4, col = 23 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Id",
          "OrderId",
          "CustomerId",
        },
      },
    },
  },
  {
    number = 4376,
    description = "ON clause - compound condition with AND",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID AND e.Salary = d.]],
    cursor = { line = 1, col = 69 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "Budget",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4377,
    description = "ON clause - compound condition with OR",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID OR e.EmployeeID = d.]],
    cursor = { line = 1, col = 72 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "ManagerID",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4378,
    description = "ON clause - parenthesized conditions",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e
JOIN Departments d ON (e.DepartmentID = d.DepartmentID) AND (e.Salary = d.]],
    cursor = { line = 1, col = 73 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "Budget",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4379,
    description = "ON clause - with BETWEEN operator",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e
JOIN Projects p ON e.HireDate BETWEEN p.]],
    cursor = { line = 1, col = 41 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "StartDate",
          "EndDate",
        },
      },
    },
  },
  {
    number = 4380,
    description = "ON clause - with IN subquery placeholder",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID IN (SELECT  FROM Departments)]],
    cursor = { line = 1, col = 54 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },

  -- ============================================================================
  -- 4381-4390: Cross-database and schema-qualified ON clauses
  -- ============================================================================
  {
    number = 4381,
    description = "ON clause - schema-qualified tables",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.Employees e JOIN dbo.Departments d ON e.]],
    cursor = { line = 0, col = 56 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4382,
    description = "ON clause - cross-database join",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM vim_dadbod_test.dbo.Employees e
JOIN TEST.dbo.Records r ON e.EmployeeID = r.]],
    cursor = { line = 1, col = 44 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "id",
          "name",
        },
      },
    },
  },
  {
    number = 4383,
    description = "ON clause - mixed schema qualification",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN hr.Benefits b ON e.EmployeeID = b.]],
    cursor = { line = 0, col = 63 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "EmployeeID",
          "BenefitID",
        },
      },
    },
  },
  {
    number = 4384,
    description = "ON clause - three-part name tables",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM vim_dadbod_test.dbo.Employees e
JOIN vim_dadbod_test.dbo.Departments d ON e.DepartmentID = d.]],
    cursor = { line = 1, col = 59 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4385,
    description = "ON clause - bracketed identifiers",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [Employees] e JOIN [Departments] d ON e.[DepartmentID] = d.]],
    cursor = { line = 0, col = 71 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4386,
    description = "ON clause - bracketed schema and table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [dbo].[Employees] e JOIN [dbo].[Departments] d ON e.]],
    cursor = { line = 0, col = 64 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4387,
    description = "ON clause - cross-schema in same database",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.Employees e JOIN hr.Benefits b ON e.EmployeeID = b.]],
    cursor = { line = 0, col = 68 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "EmployeeID",
          "BenefitID",
        },
      },
    },
  },
  {
    number = 4388,
    description = "ON clause - cross database join",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN TEST.dbo.Records r ON e.EmployeeID = r.]],
    cursor = { line = 0, col = 68 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "id",
          "name",
        },
      },
    },
  },
  {
    number = 4389,
    description = "ON clause - mixed bracketed and unbracketed",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN [Departments] d ON e.DepartmentID = d.]],
    cursor = { line = 0, col = 68 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4390,
    description = "ON clause - fully qualified with brackets",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [vim_dadbod_test].[dbo].[Employees] e
JOIN [vim_dadbod_test].[dbo].[Departments] d ON e.]],
    cursor = { line = 1, col = 48 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "EmployeeID",
        },
      },
    },
  },

  -- ============================================================================
  -- 4391-4400: Edge cases and special scenarios
  -- ============================================================================
  {
    number = 4391,
    description = "ON clause - table alias same as column name",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees EmployeeID JOIN Departments d ON EmployeeID.]],
    cursor = { line = 0, col = 67 },
    expected = {
      type = "column",
      items = {
        -- Alias EmployeeID refers to Employees table
        includes = {
          "EmployeeID",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4392,
    description = "ON clause - reserved word as alias",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees [select] JOIN Departments d ON [select].]],
    cursor = { line = 0, col = 64 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4393,
    description = "ON clause - numeric alias",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees [1] JOIN Departments [2] ON [1].]],
    cursor = { line = 0, col = 55 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4394,
    description = "ON clause - empty alias after dot (edge case)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.]],
    cursor = { line = 0, col = 48 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4395,
    description = "ON clause - whitespace handling",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON   e   .   ]],
    cursor = { line = 0, col = 57 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4396,
    description = "ON clause - tab characters",
    database = "vim_dadbod_test",
    query = "SELECT * FROM Employees e JOIN Departments d ON\te.",
    cursor = { line = 0, col = 49 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4397,
    description = "ON clause - case sensitivity (lowercase)",
    database = "vim_dadbod_test",
    query = [[select * from employees e join departments d on e.]],
    cursor = { line = 0, col = 48 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4398,
    description = "ON clause - mixed case",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees E JOIN Departments D ON E.departmentid = D.]],
    cursor = { line = 0, col = 65 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4399,
    description = "ON clause - bracketed identifiers",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN [Departments] d ON e.DepartmentID = d.]],
    cursor = { line = 0, col = 68 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4400,
    description = "ON clause - extremely long query",
    database = "vim_dadbod_test",
    query = [[SELECT e.EmployeeID, e.FirstName, e.LastName, e.Email, e.HireDate, e.Salary, e.IsActive, d.DepartmentID, d.DepartmentName, d.Budget, d.ManagerID FROM Employees e JOIN Departments d ON e.DepartmentID = d.]],
    cursor = { line = 0, col = 196 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
      },
    },
  },
}
