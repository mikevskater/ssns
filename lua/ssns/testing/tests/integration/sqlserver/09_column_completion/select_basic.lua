-- Integration Tests: Column Completion - Basic SELECT
-- Test IDs: 4101-4130
-- Tests column completion in SELECT clause

return {
  -- ============================================================================
  -- 4101-4110: Single table SELECT columns
  -- ============================================================================
  {
    number = 4101,
    description = "SELECT - columns from single table (no alias)",
    database = "vim_dadbod_test",
    query = [[SELECT  FROM Employees]],
    cursor = { line = 0, col = 7 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "LastName",
          "Email",
          "DepartmentID",
          "Salary",
          "HireDate",
          "IsActive",
        },
      },
    },
  },
  {
    number = 4102,
    description = "SELECT - columns with prefix filter",
    database = "vim_dadbod_test",
    query = [[SELECT First FROM Employees]],
    cursor = { line = 0, col = 12 },
    expected = {
      type = "column",
      items = {
        includes = {
          "FirstName",
        },
        excludes = {
          "LastName",
          "EmployeeID",
        },
      },
    },
  },
  {
    number = 4103,
    description = "SELECT - columns after existing column",
    database = "vim_dadbod_test",
    query = [[SELECT EmployeeID,  FROM Employees]],
    cursor = { line = 0, col = 19 },
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
    number = 4104,
    description = "SELECT - columns multiline",
    database = "vim_dadbod_test",
    query = [[SELECT
  EmployeeID,

FROM Employees]],
    cursor = { line = 2, col = 2 },
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
    number = 4105,
    description = "SELECT - columns from schema-qualified table",
    database = "vim_dadbod_test",
    query = [[SELECT  FROM dbo.Employees]],
    cursor = { line = 0, col = 7 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4106,
    description = "SELECT - columns from bracketed table",
    database = "vim_dadbod_test",
    query = [[SELECT  FROM [Employees]],
    cursor = { line = 0, col = 7 },
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
    number = 4107,
    description = "SELECT * then more columns",
    database = "vim_dadbod_test",
    query = [[SELECT *,  FROM Employees]],
    cursor = { line = 0, col = 10 },
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
    number = 4108,
    description = "SELECT - table-qualified column completion",
    database = "vim_dadbod_test",
    query = [[SELECT Employees. FROM Employees]],
    cursor = { line = 0, col = 17 },
    expected = {
      type = "column",
      items = {
        includes = {
          "EmployeeID",
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4109,
    description = "SELECT - columns from view",
    database = "vim_dadbod_test",
    query = [[SELECT  FROM vw_ActiveEmployees]],
    cursor = { line = 0, col = 7 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "EmployeeID",
          "FirstName",
          "LastName",
        },
      },
    },
  },
  {
    number = 4110,
    description = "SELECT - columns from synonym",
    database = "vim_dadbod_test",
    query = [[SELECT  FROM syn_Employees]],
    cursor = { line = 0, col = 7 },
    expected = {
      type = "column",
      items = {
        includes_any = {
          "EmployeeID",
          "FirstName",
        },
      },
    },
  },

  -- ============================================================================
  -- 4111-4120: SELECT with table alias
  -- ============================================================================
  {
    number = 4111,
    description = "SELECT - alias-qualified columns",
    database = "vim_dadbod_test",
    query = [[SELECT e. FROM Employees e]],
    cursor = { line = 0, col = 9 },
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
    number = 4112,
    description = "SELECT - alias-qualified with prefix",
    database = "vim_dadbod_test",
    query = [[SELECT e.First FROM Employees e]],
    cursor = { line = 0, col = 14 },
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
    number = 4113,
    description = "SELECT - unqualified columns with alias in FROM",
    database = "vim_dadbod_test",
    query = [[SELECT  FROM Employees e]],
    cursor = { line = 0, col = 7 },
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
    number = 4114,
    description = "SELECT - alias with AS keyword",
    database = "vim_dadbod_test",
    query = [[SELECT emp. FROM Employees AS emp]],
    cursor = { line = 0, col = 11 },
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
    number = 4115,
    description = "SELECT - case insensitive alias",
    database = "vim_dadbod_test",
    query = [[SELECT E. FROM Employees e]],
    cursor = { line = 0, col = 9 },
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
    number = 4116,
    description = "SELECT - multiline with alias",
    database = "vim_dadbod_test",
    query = [[SELECT
  e.EmployeeID,
  e.
FROM Employees e]],
    cursor = { line = 2, col = 4 },
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
    number = 4117,
    description = "SELECT - bracketed alias",
    database = "vim_dadbod_test",
    query = [[
      SELECT [e]. FROM Employees [e]
    ]],
    cursor = { line = 0, col = 11 },
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
    number = 4118,
    description = "SELECT - long alias name",
    database = "vim_dadbod_test",
    query = [[SELECT employees_table. FROM Employees employees_table]],
    cursor = { line = 0, col = 23 },
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
    number = 4119,
    description = "SELECT - schema.table with alias",
    database = "vim_dadbod_test",
    query = [[SELECT e. FROM dbo.Employees e]],
    cursor = { line = 0, col = 9 },
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
    number = 4120,
    description = "SELECT - multiple columns with alias prefix",
    database = "vim_dadbod_test",
    query = [[SELECT e.EmployeeID, e.FirstName, e. FROM Employees e]],
    cursor = { line = 0, col = 36 },
    expected = {
      type = "column",
      items = {
        includes = {
          "LastName",
          "DepartmentID",
          "Salary",
        },
      },
    },
  },

  -- ============================================================================
  -- 4121-4130: SELECT with multiple tables
  -- ============================================================================
  {
    number = 4121,
    description = "SELECT - columns from multiple tables (unqualified)",
    database = "vim_dadbod_test",
    query = [[SELECT  FROM Employees, Departments]],
    cursor = { line = 0, col = 7 },
    expected = {
      type = "column",
      items = {
        includes = {
          -- Should include columns from both tables
          "EmployeeID",
          "FirstName",
          "DepartmentID",
          "DepartmentName",
        },
      },
    },
  },
  {
    number = 4122,
    description = "SELECT - qualified columns from first table",
    database = "vim_dadbod_test",
    query = [[SELECT Employees. FROM Employees, Departments]],
    cursor = { line = 0, col = 17 },
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
    number = 4123,
    description = "SELECT - qualified columns from second table",
    database = "vim_dadbod_test",
    query = [[SELECT Departments. FROM Employees, Departments]],
    cursor = { line = 0, col = 19 },
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
    number = 4124,
    description = "SELECT - alias-qualified from multiple tables",
    database = "vim_dadbod_test",
    query = [[SELECT e. FROM Employees e, Departments d]],
    cursor = { line = 0, col = 9 },
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
    number = 4125,
    description = "SELECT - second alias-qualified from multiple tables",
    database = "vim_dadbod_test",
    query = [[SELECT d. FROM Employees e, Departments d]],
    cursor = { line = 0, col = 9 },
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
    number = 4126,
    description = "SELECT - mixing qualified and unqualified",
    database = "vim_dadbod_test",
    query = [[SELECT e.EmployeeID,  FROM Employees e, Departments d]],
    cursor = { line = 0, col = 21 },
    expected = {
      type = "column",
      items = {
        includes = {
          "DepartmentID",  -- Both have this
          "DepartmentName",  -- From Departments
          "FirstName",  -- From Employees
        },
      },
    },
  },
  {
    number = 4127,
    description = "SELECT - three tables unqualified",
    database = "vim_dadbod_test",
    query = [[SELECT  FROM Employees, Departments, Projects]],
    cursor = { line = 0, col = 7 },
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
    number = 4128,
    description = "SELECT - multiline multiple tables",
    database = "vim_dadbod_test",
    query = [[SELECT
  e.EmployeeID,
  d.
FROM Employees e,
     Departments d]],
    cursor = { line = 2, col = 4 },
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
    number = 4129,
    description = "SELECT - invalid alias shows no columns",
    database = "vim_dadbod_test",
    query = [[SELECT x. FROM Employees e]],
    cursor = { line = 0, col = 9 },
    expected = {
      type = "column",
      items = {
        count = 0,
      },
    },
  },
  {
    number = 4130,
    description = "SELECT - partial alias match",
    database = "vim_dadbod_test",
    query = [[SELECT emp. FROM Employees emp, Departments dept]],
    cursor = { line = 0, col = 11 },
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
}
