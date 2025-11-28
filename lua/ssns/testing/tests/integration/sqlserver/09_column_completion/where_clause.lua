-- Integration Tests: Column Completion - WHERE Clause
-- Test IDs: 4131-4160
-- Tests column completion in WHERE clause

return {
  -- ============================================================================
  -- 4131-4140: Single table WHERE clause
  -- ============================================================================
  {
    number = 4131,
    description = "WHERE - basic column completion",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE ]],
    cursor = { line = 0, col = 31 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "LastName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4132,
    description = "WHERE - column with prefix",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE First]],
    cursor = { line = 0, col = 36 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
        },
        excludes = {
          "LastName",
        },
      },
    },
  },
  {
    number = 4133,
    description = "WHERE - after = operator",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE EmployeeID = ]],
    cursor = { line = 0, col = 43 },
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
    number = 4134,
    description = "WHERE - after AND",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE EmployeeID = 1 AND ]],
    cursor = { line = 0, col = 49 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4135,
    description = "WHERE - after OR",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE EmployeeID = 1 OR ]],
    cursor = { line = 0, col = 48 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4136,
    description = "WHERE - multiline",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees
WHERE ]],
    cursor = { line = 2, col = 6 },
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
    number = 4137,
    description = "WHERE - table-qualified",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE Employees.]],
    cursor = { line = 0, col = 41 },
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
    number = 4138,
    description = "WHERE - alias-qualified",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e WHERE e.]],
    cursor = { line = 0, col = 35 },
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
    number = 4139,
    description = "WHERE - with IN clause",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE DepartmentID IN (SELECT  FROM Departments)]],
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
    number = 4140,
    description = "WHERE - complex condition",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE (EmployeeID > 5 AND ) OR DepartmentID = 1]],
    cursor = { line = 0, col = 50 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "Salary",
        },
      },
    },
  },

  -- ============================================================================
  -- 4141-4150: Multi-table WHERE clause
  -- ============================================================================
  {
    number = 4141,
    description = "WHERE - columns from multiple tables",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e, Departments d WHERE ]],
    cursor = { line = 0, col = 47 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentID",
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4142,
    description = "WHERE - qualified from first table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e, Departments d WHERE e.]],
    cursor = { line = 0, col = 49 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
        excludes = {
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4143,
    description = "WHERE - qualified from second table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e, Departments d WHERE d.]],
    cursor = { line = 0, col = 49 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "DepartmentName",
        },
        excludes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4144,
    description = "WHERE - join condition style",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e, Departments d WHERE e.DepartmentID = d.]],
    cursor = { line = 0, col = 66 },
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
    number = 4145,
    description = "WHERE - after join condition AND",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e, Departments d WHERE e.DepartmentID = d.DepartmentID AND e.]],
    cursor = { line = 0, col = 85 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "Salary",
        },
      },
    },
  },
  {
    number = 4146,
    description = "WHERE - three tables",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e, Departments d, Projects p WHERE p.]],
    cursor = { line = 0, col = 61 },
    expected = {
      type = "column",
      items = {
        includes = {
          "ProjectID",
          "ProjectName",
        },
        excludes = {
          "FirstName",
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4147,
    description = "WHERE - multiline multi-table",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees e,
     Departments d
WHERE e.DepartmentID = d.DepartmentID
  AND e.]],
    cursor = { line = 4, col = 8 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "Salary",
        },
      },
    },
  },
  {
    number = 4148,
    description = "WHERE - schema-qualified table multi",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.Employees e, dbo.Departments d WHERE e.]],
    cursor = { line = 0, col = 57 },
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
    number = 4149,
    description = "WHERE - LIKE operator",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE  LIKE '%John%']],
    cursor = { line = 0, col = 31 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4150,
    description = "WHERE - BETWEEN operator",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE  BETWEEN 1 AND 10]],
    cursor = { line = 0, col = 31 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "Salary",
        },
      },
    },
  },

  -- ============================================================================
  -- 4151-4160: WHERE with JOINs
  -- ============================================================================
  {
    number = 4151,
    description = "WHERE - after JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID WHERE ]],
    cursor = { line = 0, col = 88 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4152,
    description = "WHERE - qualified after JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID WHERE e.]],
    cursor = { line = 0, col = 90 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
        },
        excludes = {
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4153,
    description = "WHERE - after multiple JOINs",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
JOIN Projects p ON d.DepartmentID = p.DepartmentID
WHERE ]],
    cursor = { line = 3, col = 6 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "DepartmentName",
          "ProjectName",
        },
      },
    },
  },
  {
    number = 4154,
    description = "WHERE - LEFT JOIN columns",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e LEFT JOIN Departments d ON e.DepartmentID = d.DepartmentID WHERE d.]],
    cursor = { line = 0, col = 95 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4155,
    description = "WHERE - IS NULL check on nullable column",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE  IS NULL]],
    cursor = { line = 0, col = 31 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Email",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4156,
    description = "WHERE - NOT EXISTS subquery",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e WHERE NOT EXISTS (SELECT 1 FROM Departments d WHERE d.DepartmentID = e.)]],
    cursor = { line = 0, col = 101 },
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
    number = 4157,
    description = "WHERE - correlated subquery outer table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e WHERE Salary > (SELECT AVG(Salary) FROM Employees WHERE DepartmentID = e.)]],
    cursor = { line = 0, col = 100 },
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
    number = 4158,
    description = "WHERE - complex boolean expression",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e WHERE (e.DepartmentID = 1 OR e.DepartmentID = 2) AND e. > 50000]],
    cursor = { line = 0, col = 80 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Salary",
        },
      },
    },
  },
  {
    number = 4159,
    description = "WHERE - CASE expression",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE CASE WHEN  > 50000 THEN 1 ELSE 0 END = 1]],
    cursor = { line = 0, col = 41 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Salary",
        },
      },
    },
  },
  {
    number = 4160,
    description = "WHERE - function call parameter",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE YEAR() = 2024]],
    cursor = { line = 0, col = 36 },
    expected = {
      type = "column",
      items = {
        includes = {
          "HireDate",
        },
      },
    },
  },
}
