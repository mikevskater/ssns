-- Integration Tests: Table Completion - Schema-Qualified
-- Test IDs: 4021-4040
-- Tests schema-qualified table completion (dbo., hr., etc.)

return {
  -- ============================================================================
  -- 4021-4030: Schema-qualified table completion
  -- ============================================================================
  {
    number = 4021,
    description = "Schema-qualified - tables in dbo schema",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.]],
    cursor = { line = 0, col = 18 },
    expected = {
      type = "table",
      items = {
        includes = {
          -- Tables in dbo schema (8)
          "Employees",
          "Departments",
          "Projects",
          "Customers",
          "Orders",
          "Products",
          "Regions",
          "Countries",
          -- Views in dbo schema (3)
          "vw_ActiveEmployees",
          "vw_DepartmentSummary",
          "vw_ProjectStatus",
          -- Synonyms in dbo schema (4)
          "syn_ActiveEmployees",
          "syn_Depts",
          "syn_Employees",
          "syn_HRBenefits",
          -- Table Functions in dbo schema (2)
          "fn_GetEmployeesBySalaryRange",
          "GetCustomerOrders",
        },
        excludes = {
          -- hr schema objects should NOT appear
          "Benefits",
          -- Stored procedures should NOT appear
          "usp_GetEmployeesByDepartment",
          "usp_InsertEmployee",
          -- Scalar functions should NOT appear
          "fn_CalculateYearsOfService",
          "fn_GetEmployeeFullName",
        },
      },
    },
  },
  {
    number = 4022,
    description = "Schema-qualified - tables in hr schema",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM hr.]],
    cursor = { line = 0, col = 17 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Benefits",
        },
        excludes = {
          -- dbo schema objects should NOT appear
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4023,
    description = "Schema-qualified - bracketed schema [dbo].",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [dbo].]],
    cursor = { line = 0, col = 20 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4024,
    description = "Schema-qualified - prefix filter after schema",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.Emp]],
    cursor = { line = 0, col = 21 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
        },
        excludes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4025,
    description = "Schema-qualified - views in schema",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.vw_]],
    cursor = { line = 0, col = 21 },
    expected = {
      type = "table",
      items = {
        includes = {
          "vw_ActiveEmployees",
          "vw_DepartmentSummary",
          "vw_ProjectStatus",
        },
      },
    },
  },
  {
    number = 4026,
    description = "Schema-qualified - synonyms in schema",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.syn_]],
    cursor = { line = 0, col = 22 },
    expected = {
      type = "table",
      items = {
        includes = {
          "syn_ActiveEmployees",
          "syn_Depts",
          "syn_Employees",
        },
      },
    },
  },
  {
    number = 4027,
    description = "Schema-qualified - multiline query",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM dbo.]],
    cursor = { line = 1, col = 9 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },
  {
    number = 4028,
    description = "Schema-qualified - second table in FROM",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e, dbo.]],
    cursor = { line = 0, col = 31 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4029,
    description = "Schema-qualified - Branch_Prod database tables",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Branch_Prod.dbo.]],
    cursor = { line = 0, col = 30 },
    expected = {
      type = "table",
      items = {
        includes = {
          "central_division",
          "eastern_division",
          "western_division",
          "division_metrics",
          "vw_all_divisions",
        },
      },
    },
  },
  {
    number = 4030,
    description = "Schema-qualified - case insensitive schema",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM DBO.]],
    cursor = { line = 0, col = 18 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },

  -- ============================================================================
  -- 4031-4040: Schema completion (typing after FROM before .)
  -- ============================================================================
  {
    number = 4031,
    description = "Schema completion - typing 'd' should suggest schemas",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM d]],
    cursor = { line = 0, col = 15 },
    expected = {
      -- Could be either schema or table starting with 'd'
      type = "mixed",
      items = {
        includes = {
          "dbo",
          "Departments",
        },
      },
    },
  },
  {
    number = 4032,
    description = "Schema completion - all schemas available",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM ]],
    cursor = { line = 0, col = 14 },
    expected = {
      type = "table",
      items = {
        -- Schemas should be available alongside tables
        includes = {
          "Employees",  -- table
        },
      },
    },
  },
  {
    number = 4033,
    description = "Schema-qualified - after JOIN keyword",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN dbo.]],
    cursor = { line = 0, col = 35 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4034,
    description = "Schema-qualified - after LEFT JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e LEFT JOIN dbo.]],
    cursor = { line = 0, col = 40 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4035,
    description = "Schema-qualified - after INNER JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e INNER JOIN dbo.]],
    cursor = { line = 0, col = 41 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
        },
      },
    },
  },
  {
    number = 4036,
    description = "Schema-qualified - with bracketed table names",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.[Emp]],
    cursor = { line = 0, col = 22 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
        },
      },
    },
  },
  {
    number = 4037,
    description = "Schema completion - sys schema (if enabled)",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM sys.]],
    cursor = { line = 0, col = 18 },
    expected = {
      type = "table",
      items = {
        -- sys schema contains system views
        includes_any = {
          "objects",
          "tables",
          "columns",
        },
      },
    },
  },
  {
    number = 4038,
    description = "Schema-qualified - empty schema should show nothing",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM nonexistent_schema.]],
    cursor = { line = 0, col = 33 },
    expected = {
      type = "table",
      items = {
        count = 0,
      },
    },
  },
  {
    number = 4039,
    description = "Schema-qualified - UPDATE statement",
    database = "vim_dadbod_test",
    query = [[UPDATE dbo.]],
    cursor = { line = 0, col = 11 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
        excludes = {
          -- Views typically excluded from UPDATE
          "vw_ActiveEmployees",
        },
      },
    },
  },
  {
    number = 4040,
    description = "Schema-qualified - DELETE statement",
    database = "vim_dadbod_test",
    query = [[DELETE FROM dbo.]],
    cursor = { line = 0, col = 16 },
    expected = {
      type = "table",
      items = {
        includes = {
          "Employees",
          "Departments",
        },
      },
    },
  },
}
