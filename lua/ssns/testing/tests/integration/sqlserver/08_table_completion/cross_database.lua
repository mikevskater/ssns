-- Integration Tests: Table Completion - Cross-Database Queries
-- Test IDs: 4041-4060
-- Tests cross-database completion ([OtherDB].[schema].[table])

return {
  -- ============================================================================
  -- 4041-4050: Database completion (first part of qualified name)
  -- ============================================================================
  {
    number = 4041,
    description = "Cross-database - database names should be suggested",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM ]],
    cursor = { line = 0, col = 14 },
    expected = {
      type = "object",
      items = {
        includes = {
          -- All databases including current
          "vim_dadbod_test",
          "TEST",
          "Branch_Prod",
          -- Schemas in current DB
          "dbo",
          "hr",
          -- All FROM-selectable objects from current database (18 total)
          -- dbo tables (8)
          "Regions",
          "Countries",
          "Departments",
          "Employees",
          "Customers",
          "Orders",
          "Products",
          "Projects",
          -- dbo views (3)
          "vw_ActiveEmployees",
          "vw_DepartmentSummary",
          "vw_ProjectStatus",
          -- dbo synonyms (4)
          "syn_ActiveEmployees",
          "syn_Depts",
          "syn_Employees",
          "syn_HRBenefits",
          -- dbo table functions (2)
          "fn_GetEmployeesBySalaryRange",
          "GetCustomerOrders",
          -- hr tables (1)
          "Benefits",
        },
      },
    },
  },
  {
    number = 4042,
    description = "Cross-database - after typing database prefix",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM TEST]],
    cursor = { line = 0, col = 18 },
    expected = {
      type = "database",
      items = {
        includes = {
          "TEST",
        },
      },
    },
  },
  {
    number = 4043,
    description = "Cross-database - schemas in other database",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM TEST.]],
    cursor = { line = 0, col = 19 },
    expected = {
      type = "schema",
      items = {
        includes = {
          "dbo",
        },
      },
    },
  },
  {
    number = 4044,
    description = "Cross-database - tables after database.schema.",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM TEST.dbo.]],
    cursor = { line = 0, col = 23 },
    expected = {
      type = "table",
      items = {
        -- All FROM-selectable objects in TEST.dbo schema (2 total)
        includes_any = {
          "Records",
          "syn_MainEmployees",
        },
      },
    },
  },
  {
    number = 4045,
    description = "Cross-database - bracketed database name",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [TEST].]],
    cursor = { line = 0, col = 21 },
    expected = {
      type = "schema",
      items = {
        includes = {
          "dbo",
        },
      },
    },
  },
  {
    number = 4046,
    description = "Cross-database - bracketed database and schema",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [TEST].[dbo].]],
    cursor = { line = 0, col = 27 },
    expected = {
      type = "table",
      items = {
        -- Tables in [TEST].[dbo] schema
        includes_any = {
          "Records",
        },
      },
    },
  },
  {
    number = 4047,
    description = "Cross-database - Branch_Prod database",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Branch_Prod.]],
    cursor = { line = 0, col = 26 },
    expected = {
      type = "schema",
      items = {
        includes = {
          "dbo",
        },
      },
    },
  },
  {
    number = 4048,
    description = "Cross-database - database completion in JOIN",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e JOIN TEST.]],
    cursor = { line = 0, col = 36 },
    expected = {
      type = "schema",
      items = {
        includes = {
          "dbo",
        },
      },
    },
  },
  {
    number = 4049,
    description = "Cross-database - full three-part name completion",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM TEST.dbo.R]],
    cursor = { line = 0, col = 24 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "Records",
        },
      },
    },
  },
  {
    number = 4050,
    description = "Cross-database - master database system tables",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM master.sys.]],
    cursor = { line = 0, col = 25 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "databases",
          "objects",
          "tables",
        },
      },
    },
  },

  -- ============================================================================
  -- 4051-4060: Cross-database in various contexts
  -- ============================================================================
  {
    number = 4051,
    description = "Cross-database - in subquery",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees WHERE DeptID IN (SELECT ID FROM TEST.dbo.)]],
    cursor = { line = 0, col = 65 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "Records",
        },
      },
    },
  },
  {
    number = 4052,
    description = "Cross-database - multiline query",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM vim_dadbod_test.dbo.Employees e
JOIN TEST.dbo.]],
    cursor = { line = 2, col = 14 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "Records",
        },
      },
    },
  },
  {
    number = 4053,
    description = "Cross-database - database with underscore",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM vim_dadbod_test.]],
    cursor = { line = 0, col = 30 },
    expected = {
      type = "schema",
      items = {
        includes = {
          "dbo",
          "hr",
        },
      },
    },
  },
  {
    number = 4054,
    description = "Cross-database - current database explicit",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM vim_dadbod_test.dbo.]],
    cursor = { line = 0, col = 34 },
    expected = {
      type = "table",
      items = {
        includes = {
          -- All FROM-selectable objects in vim_dadbod_test.dbo (17 total)
          -- Tables (8)
          "Regions",
          "Countries",
          "Departments",
          "Employees",
          "Customers",
          "Orders",
          "Products",
          "Projects",
          -- Views (3)
          "vw_ActiveEmployees",
          "vw_DepartmentSummary",
          "vw_ProjectStatus",
          -- Synonyms (4)
          "syn_ActiveEmployees",
          "syn_Depts",
          "syn_Employees",
          "syn_HRBenefits",
          -- Table Functions (2)
          "fn_GetEmployeesBySalaryRange",
          "GetCustomerOrders",
        },
      },
    },
  },
  {
    number = 4055,
    description = "Cross-database - case insensitive database name",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM test.]],
    cursor = { line = 0, col = 19 },
    expected = {
      type = "schema",
      items = {
        includes = {
          "dbo",
        },
      },
    },
  },
  {
    number = 4056,
    description = "Cross-database - UNION query second part",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees
UNION ALL
SELECT * FROM TEST.dbo.]],
    cursor = { line = 2, col = 23 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "Records",
        },
      },
    },
  },
  {
    number = 4057,
    description = "Cross-database - INSERT INTO cross-db",
    database = "vim_dadbod_test",
    query = [[INSERT INTO TEST.dbo.]],
    cursor = { line = 0, col = 21 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "Records",
        },
      },
    },
  },
  {
    number = 4058,
    description = "Cross-database - UPDATE cross-db table",
    database = "vim_dadbod_test",
    query = [[UPDATE TEST.dbo.]],
    cursor = { line = 0, col = 16 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "Records",
        },
      },
    },
  },
  {
    number = 4059,
    description = "Cross-database - DELETE FROM cross-db",
    database = "vim_dadbod_test",
    query = [[DELETE FROM TEST.dbo.]],
    cursor = { line = 0, col = 21 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "Records",
        },
      },
    },
  },
  {
    number = 4060,
    description = "Cross-database - tempdb access",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM tempdb.sys.]],
    cursor = { line = 0, col = 25 },
    expected = {
      type = "table",
      items = {
        includes_any = {
          "objects",
          "tables",
        },
      },
    },
  },
}
