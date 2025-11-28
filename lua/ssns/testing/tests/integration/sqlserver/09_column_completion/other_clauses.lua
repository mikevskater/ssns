-- Integration Tests: Column Completion - Other Clauses
-- Test IDs: 4191-4230
-- Tests column completion in ORDER BY, GROUP BY, HAVING, and other clauses

return {
  -- ============================================================================
  -- 4191-4200: ORDER BY clause
  -- ============================================================================
  {
    number = 4191,
    description = "ORDER BY - basic column completion",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees ORDER BY ]],
    cursor = { line = 0, col = 34 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "LastName",
          "Salary",
        },
      },
    },
  },
  {
    number = 4192,
    description = "ORDER BY - with prefix",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees ORDER BY First]],
    cursor = { line = 0, col = 39 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4193,
    description = "ORDER BY - alias-qualified",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e ORDER BY e.]],
    cursor = { line = 0, col = 38 },
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
    number = 4194,
    description = "ORDER BY - second column after comma",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees ORDER BY LastName, ]],
    cursor = { line = 0, col = 43 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4195,
    description = "ORDER BY - after ASC",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees ORDER BY LastName ASC, ]],
    cursor = { line = 0, col = 47 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4196,
    description = "ORDER BY - after DESC",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees ORDER BY LastName DESC, ]],
    cursor = { line = 0, col = 48 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4197,
    description = "ORDER BY - multi-table JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID ORDER BY ]],
    cursor = { line = 0, col = 92 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4198,
    description = "ORDER BY - qualified from joined table",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID ORDER BY d.]],
    cursor = { line = 0, col = 94 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentName",
        },
        excludes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4199,
    description = "ORDER BY - multiline",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees
ORDER BY ]],
    cursor = { line = 2, col = 9 },
    expected = {
      type = "column",
      items = {
        includes = {
          "LastName",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4200,
    description = "ORDER BY - after WHERE clause",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE DepartmentID = 1 ORDER BY ]],
    cursor = { line = 0, col = 58 },
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
  -- 4201-4210: GROUP BY clause
  -- ============================================================================
  {
    number = 4201,
    description = "GROUP BY - basic column completion",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY ]],
    cursor = { line = 0, col = 55 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4202,
    description = "GROUP BY - second column",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, Email, COUNT(*) FROM Employees GROUP BY DepartmentID, ]],
    cursor = { line = 0, col = 76 },
    expected = {
      type = "column",
      items = {
        includes = {
          "Email",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4203,
    description = "GROUP BY - alias-qualified",
    database = "vim_dadbod_test",
    query = [[SELECT e.DepartmentID, COUNT(*) FROM Employees e GROUP BY e.]],
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
    number = 4204,
    description = "GROUP BY - multi-table",
    database = "vim_dadbod_test",
    query = [[SELECT d.DepartmentName, COUNT(*) FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID GROUP BY ]],
    cursor = { line = 0, col = 116 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentName",
          "FirstName",
        },
      },
    },
  },
  {
    number = 4205,
    description = "GROUP BY - qualified from specific table",
    database = "vim_dadbod_test",
    query = [[SELECT d.DepartmentName, COUNT(*) FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID GROUP BY d.]],
    cursor = { line = 0, col = 118 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentName",
        },
        excludes = {
          "FirstName",
        },
      },
    },
  },
  {
    number = 4206,
    description = "GROUP BY - multiline",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*)
FROM Employees
GROUP BY ]],
    cursor = { line = 2, col = 9 },
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
    number = 4207,
    description = "GROUP BY - with WHERE",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*) FROM Employees WHERE Salary > 50000 GROUP BY ]],
    cursor = { line = 0, col = 76 },
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
    number = 4208,
    description = "GROUP BY - multiple grouping columns",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, Email, COUNT(*) FROM Employees GROUP BY DepartmentID, Email, ]],
    cursor = { line = 0, col = 85 },
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
    number = 4209,
    description = "GROUP BY - with prefix filter",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY Dep]],
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
  {
    number = 4210,
    description = "GROUP BY - ROLLUP clause",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY ROLLUP()]],
    cursor = { line = 0, col = 62 },
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
  -- 4211-4220: HAVING clause
  -- ============================================================================
  {
    number = 4211,
    description = "HAVING - basic column completion",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY DepartmentID HAVING ]],
    cursor = { line = 0, col = 75 },
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
    number = 4212,
    description = "HAVING - after aggregate function",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY DepartmentID HAVING COUNT() > 5]],
    cursor = { line = 0, col = 81 },
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
    number = 4213,
    description = "HAVING - SUM function",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, SUM(Salary) FROM Employees GROUP BY DepartmentID HAVING SUM() > 100000]],
    cursor = { line = 0, col = 81 },
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
    number = 4214,
    description = "HAVING - alias-qualified",
    database = "vim_dadbod_test",
    query = [[SELECT e.DepartmentID, COUNT(*) FROM Employees e GROUP BY e.DepartmentID HAVING e.]],
    cursor = { line = 0, col = 81 },
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
    number = 4215,
    description = "HAVING - multi-table",
    database = "vim_dadbod_test",
    query = [[SELECT d.DepartmentName, COUNT(*) FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID GROUP BY d.DepartmentName HAVING ]],
    cursor = { line = 0, col = 139 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4216,
    description = "HAVING - AND condition",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*) FROM Employees GROUP BY DepartmentID HAVING COUNT(*) > 5 AND ]],
    cursor = { line = 0, col = 93 },
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
    number = 4217,
    description = "HAVING - complex aggregate",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID FROM Employees GROUP BY DepartmentID HAVING AVG() > 50000]],
    cursor = { line = 0, col = 71 },
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
    number = 4218,
    description = "HAVING - multiline query",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID, COUNT(*)
FROM Employees
GROUP BY DepartmentID
HAVING ]],
    cursor = { line = 3, col = 7 },
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
    number = 4219,
    description = "HAVING - MIN/MAX function",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID FROM Employees GROUP BY DepartmentID HAVING MAX() < '2020-01-01']],
    cursor = { line = 0, col = 71 },
    expected = {
      type = "column",
      items = {
        includes = {
          "HireDate",
        },
      },
    },
  },
  {
    number = 4220,
    description = "HAVING - nested aggregate",
    database = "vim_dadbod_test",
    query = [[SELECT DepartmentID FROM Employees GROUP BY DepartmentID HAVING COUNT(DISTINCT ) > 1]],
    cursor = { line = 0, col = 80 },
    expected = {
      type = "column",
      items = {
        includes = {
          "ManagerID",
          "FirstName",
        },
      },
    },
  },

  -- ============================================================================
  -- 4221-4230: UPDATE SET and INSERT clauses
  -- ============================================================================
  {
    number = 4221,
    description = "UPDATE SET - column list",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET ]],
    cursor = { line = 0, col = 21 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
          "Salary",
        },
      },
    },
  },
  {
    number = 4222,
    description = "UPDATE SET - second column",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET FirstName = 'John', ]],
    cursor = { line = 0, col = 42 },
    expected = {
      type = "column",
      items = {
        includes = {
          "LastName",
          "Salary",
        },
      },
    },
  },
  {
    number = 4223,
    description = "UPDATE SET - value side from same table",
    database = "vim_dadbod_test",
    query = [[UPDATE Employees SET Salary = Salary + ]],
    cursor = { line = 0, col = 40 },
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
    number = 4224,
    description = "UPDATE FROM - column from joined table",
    database = "vim_dadbod_test",
    query = [[UPDATE e SET e.Salary = d. FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID]],
    cursor = { line = 0, col = 26 },
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
    number = 4225,
    description = "INSERT columns - column list",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees (]],
    cursor = { line = 0, col = 23 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
          "LastName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4226,
    description = "INSERT columns - second column",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees (FirstName, ]],
    cursor = { line = 0, col = 34 },
    expected = {
      type = "column",
      items = {
        includes = {
          "LastName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4227,
    description = "INSERT columns - schema-qualified table",
    database = "vim_dadbod_test",
    query = [[INSERT INTO dbo.Employees (]],
    cursor = { line = 0, col = 27 },
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
    number = 4228,
    description = "INSERT SELECT - columns in subquery",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees (FirstName, LastName) SELECT  FROM Employees]],
    cursor = { line = 0, col = 51 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4229,
    description = "INSERT multiline - column list",
    database = "vim_dadbod_test",
    query = [[INSERT INTO Employees
  (FirstName,
   ]],
    cursor = { line = 2, col = 3 },
    expected = {
      type = "column",
      items = {
        includes = {
          "LastName",
          "DepartmentID",
        },
      },
    },
  },
  {
    number = 4230,
    description = "DELETE WHERE - column completion",
    database = "vim_dadbod_test",
    query = [[DELETE FROM Employees WHERE ]],
    cursor = { line = 0, col = 28 },
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
}
