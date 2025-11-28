-- Integration Tests: Column Completion - JOIN ON Clause
-- Test IDs: 4161-4190
-- Tests column completion in JOIN ON clauses with fuzzy matching

return {
  -- ============================================================================
  -- 4161-4170: Basic ON clause completion
  -- ============================================================================
  {
    number = 4161,
    description = "ON clause - basic left side completion",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON ]],
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
    number = 4162,
    description = "ON clause - alias-qualified left side",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.]],
    cursor = { line = 0, col = 50 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "EmployeeID",
        },
        excludes = {
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4163,
    description = "ON clause - right side after =",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = ]],
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
    number = 4164,
    description = "ON clause - right side alias-qualified",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.]],
    cursor = { line = 0, col = 67 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
        },
        excludes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4165,
    description = "ON clause - compound condition AND",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID AND e.]],
    cursor = { line = 0, col = 85 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4166,
    description = "ON clause - multiline",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees e
JOIN Departments d
  ON e.DepartmentID = d.DepartmentID
  AND e. = d.ManagerID]],
    cursor = { line = 4, col = 8 },
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
    number = 4167,
    description = "ON clause - LEFT JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e LEFT JOIN Departments d ON e.]],
    cursor = { line = 0, col = 55 },
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
    number = 4168,
    description = "ON clause - RIGHT JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Departments d RIGHT JOIN Employees e ON e.]],
    cursor = { line = 0, col = 56 },
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
    number = 4169,
    description = "ON clause - FULL OUTER JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e FULL OUTER JOIN Departments d ON e.]],
    cursor = { line = 0, col = 61 },
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
    number = 4170,
    description = "ON clause - schema-qualified tables",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.Employees e JOIN dbo.Departments d ON e.]],
    cursor = { line = 0, col = 58 },
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
  -- 4171-4180: Multi-table ON clause (chained JOINs)
  -- ============================================================================
  {
    number = 4171,
    description = "ON clause - second JOIN left side",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN Projects p ON ]],
    cursor = { line = 0, col = 101 },
    expected = {
      type = "column",
      items = {
        includes = {
          "ProjectID",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4172,
    description = "ON clause - second JOIN alias-qualified",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN Projects p ON p.]],
    cursor = { line = 0, col = 103 },
    expected = {
      type = "column",
      items = {
        includes = {
          "ProjectID",
          "ProjectName",
        },
        excludes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4173,
    description = "ON clause - second JOIN linking to first table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN Projects p ON p.ProjectID = e.]],
    cursor = { line = 0, col = 118 },
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
    number = 4174,
    description = "ON clause - second JOIN linking to second table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN Projects p ON p.DepartmentID = d.]],
    cursor = { line = 0, col = 118 },
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
    number = 4175,
    description = "ON clause - third JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
JOIN Projects p ON p.DepartmentID = d.DepartmentID
JOIN Customers c ON c.Id = ]],
    cursor = { line = 4, col = 28 },
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
    number = 4176,
    description = "ON clause - all tables available",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN Projects p ON ]],
    cursor = { line = 0, col = 101 },
    expected = {
      type = "column",
      items = {
        -- All aliases should work
        includes_any = {
          "EmployeeID",
          "DepartmentID",
          "ProjectID",
        },
      },
    },
  },
  {
    number = 4177,
    description = "ON clause - complex multi-join multiline",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees e
INNER JOIN Departments d
  ON e.DepartmentID = d.DepartmentID
LEFT JOIN Projects p
  ON d.DepartmentID = p.DepartmentID
  AND p. > 0]],
    cursor = { line = 6, col = 8 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Budget",
          "ProjectID",
        },
      },
    },
  },
  {
    number = 4178,
    description = "ON clause - self-join",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Employees m ON e.ManagerID = m.]],
    cursor = { line = 0, col = 62 },
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
    number = 4179,
    description = "ON clause - self-join second alias",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Employees m ON m.]],
    cursor = { line = 0, col = 48 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "ManagerID",
        },
      },
    },
  },
  {
    number = 4180,
    description = "ON clause - cross-schema join",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.Employees e JOIN hr.Benefits b ON e.EmployeeID = b.]],
    cursor = { line = 0, col = 69 },
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

  -- ============================================================================
  -- 4181-4190: ON clause with type compatibility and fuzzy matching
  -- ============================================================================
  {
    number = 4181,
    description = "ON clause - FK column suggestion (DepartmentID)",
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
    number = 4182,
    description = "ON clause - FK column suggestion priority",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Orders o JOIN Customers c ON o.CustomerId = c.]],
    cursor = { line = 0, col = 60 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Id",
        },
      },
    },
  },
  {
    number = 4183,
    description = "ON clause - type-compatible numeric columns",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.]],
    cursor = { line = 0, col = 67 },
    expected = {
      type = "column",
      items = {
        -- DepartmentID should be suggested first due to FK match
        includes = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4184,
    description = "ON clause - fuzzy name matching (ID vs _ID)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.]],
    cursor = { line = 0, col = 69 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4185,
    description = "ON clause - fuzzy matching EmployeeID vs EmpID",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Orders o ON e.EmployeeID = o.]],
    cursor = { line = 0, col = 60 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "EmployeeId",
        },
      },
    },
  },
  {
    number = 4186,
    description = "ON clause - should not suggest incompatible types",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.FirstName = d.]],
    cursor = { line = 0, col = 64 },
    expected = {
      type = "column",
      items = {
        -- String column should suggest string columns
        includes_any = {
          "DepartmentName",
        },
        excludes = {
          "DepartmentID",  -- Not type-compatible with FirstName
        },
      },
    },
  },
  {
    number = 4187,
    description = "ON clause - numeric left side suggests numeric right",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.Salary = d.]],
    cursor = { line = 0, col = 60 },
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
    number = 4188,
    description = "ON clause - date type compatibility",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Projects p ON e.HireDate = p.]],
    cursor = { line = 0, col = 60 },
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
    number = 4189,
    description = "ON clause - complex condition with mixed types",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID AND e.EmployeeID = d.]],
    cursor = { line = 0, col = 101 },
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
    number = 4190,
    description = "ON clause - OR condition type compatibility",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID OR e.EmployeeID = d.]],
    cursor = { line = 0, col = 101 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "ManagerID",
        },
      },
    },
  },
}
