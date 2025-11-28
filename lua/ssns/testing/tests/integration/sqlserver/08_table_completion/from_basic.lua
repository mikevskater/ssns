-- Integration Tests: Table Completion - Basic FROM clause
-- Test IDs: 4001-4020
-- Tests basic table, view, synonym completion in FROM clause

return {
  -- ============================================================================
  -- 4001-4005: Basic FROM with no prefix (current database objects)
  -- ============================================================================
  {
    number = 4001,
    description = "FROM clause - all tables in current database",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM █]],
    expected = {
      type = "table",
      -- Should include databases, schemas, and all FROM-selectable objects from current DB
      items = {
        includes = {
          -- Databases
          "TEST",
          "Branch_Prod",
          "vim_dadbod_test",
          -- Schemas in current DB
          "dbo",
          "hr",
          -- Tables in dbo schema (8)
          "Regions",
          "Countries",
          "Departments",
          "Employees",
          "Customers",
          "Orders",
          "Products",
          "Projects",
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
          -- Tables in hr schema (1)
          "Benefits",
        },
        excludes = {
          -- Should NOT include procedures or scalar functions
          "usp_GetEmployeesByDepartment",
          "usp_InsertEmployee",
          "fn_CalculateYearsOfService",
          "fn_GetEmployeeFullName",
        },
      },
    },
  },
  {
    number = 4002,
    description = "FROM clause - views should be included",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM █]],
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
    number = 4003,
    description = "FROM clause - synonyms should be included",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "syn_ActiveEmployees",
          "syn_Depts",
          "syn_Employees",
          "syn_HRBenefits",
        },
      },
    },
  },
  {
    number = 4004,
    description = "FROM clause - multiline query",
    database = "vim_dadbod_test",
    query = [[SELECT
  *
FROM █]],
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
    number = 4005,
    description = "FROM clause - after newline with space",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM █]],
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
  -- 4006-4010: FROM with prefix filtering
  -- ============================================================================
  {
    number = 4006,
    description = "FROM clause - prefix filter 'Emp'",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Emp█]],
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
    number = 4007,
    description = "FROM clause - prefix filter 'vw_'",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM vw_█]],
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
    number = 4008,
    description = "FROM clause - prefix filter 'syn_'",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM syn_█]],
    expected = {
      type = "table",
      items = {
        includes = {
          "syn_ActiveEmployees",
          "syn_Depts",
          "syn_Employees",
          "syn_HRBenefits",
        },
      },
    },
  },
  {
    number = 4009,
    description = "FROM clause - prefix filter case insensitive",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM emp█]],
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
    number = 4010,
    description = "FROM clause - no matches for invalid prefix",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM xyz_nonexistent█]],
    expected = {
      type = "table",
      items = {
        count = 0,
      },
    },
  },

  -- ============================================================================
  -- 4011-4015: FROM with comma-separated tables (second table)
  -- ============================================================================
  {
    number = 4011,
    description = "FROM clause - second table after comma",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees, █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Departments",
          "Projects",
        },
      },
    },
  },
  {
    number = 4012,
    description = "FROM clause - third table after two commas",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees, Departments, █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Projects",
          "Orders",
        },
      },
    },
  },
  {
    number = 4013,
    description = "FROM clause - second table on new line",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees,
  █]],
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
    number = 4014,
    description = "FROM clause - second table with prefix",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees, Dep█]],
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
    number = 4015,
    description = "FROM clause - multiple tables multiline",
    database = "vim_dadbod_test",
    query = [[SELECT *
FROM Employees e,
     Departments d,
     █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Projects",
        },
      },
    },
  },

  -- ============================================================================
  -- 4016-4020: FROM with tables that have aliases
  -- ============================================================================
  {
    number = 4016,
    description = "FROM clause - completion after table with alias",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees e, █]],
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
    number = 4017,
    description = "FROM clause - completion after table with AS alias",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees AS e, █]],
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
    number = 4018,
    description = "FROM clause - completion after bracketed table with alias",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM [Employees] e, █]],
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
    number = 4019,
    description = "FROM clause - completion after schema.table alias",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM dbo.Employees e, █]],
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
    number = 4020,
    description = "FROM clause - tables with varying alias styles",
    database = "vim_dadbod_test",
    query = [[SELECT * FROM Employees emp, Departments AS dept, █]],
    expected = {
      type = "table",
      items = {
        includes = {
          "Projects",
        },
      },
    },
  },
}
