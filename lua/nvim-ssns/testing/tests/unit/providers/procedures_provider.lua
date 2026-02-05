-- Test file: procedures_provider.lua
-- IDs: 3351-3400
-- Tests: Procedure completion for EXEC/EXECUTE statements
--
-- Test categories:
-- - 3351-3365: EXEC/EXECUTE completion
-- - 3366-3380: Schema-qualified procedures
-- - 3381-3395: Procedure metadata
-- - 3396-3400: Edge cases

return {
  -- ========================================
  -- EXEC/EXECUTE Completion (3351-3365)
  -- ========================================

  {
    id = 3351,
    type = "provider",
    provider = "procedures",
    name = "Basic EXEC procedure completion",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"sp_SearchEmployees", "usp_GetEmployeesByDepartment"} },
    },
  },

  {
    id = 3352,
    type = "provider",
    provider = "procedures",
    name = "EXECUTE keyword alternative",
    input = "EXECUTE |",
    cursor = { line = 1, col = 9 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"sp_SearchEmployees", "usp_GetEmployeesByDepartment"} },
    },
  },

  {
    id = 3353,
    type = "provider",
    provider = "procedures",
    name = "Partial prefix 'sp_'",
    input = "EXEC sp_|",
    cursor = { line = 1, col = 9 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"sp_SearchEmployees", "sp_help", "sp_who"}, excludes = {"usp_GetEmployeesByDepartment"} },
    },
  },

  {
    id = 3354,
    type = "provider",
    provider = "procedures",
    name = "Partial prefix 'usp_'",
    input = "EXEC usp_|",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"usp_GetEmployeesByDepartment", "usp_UpdateEmployee"}, excludes = {"sp_SearchEmployees"} },
    },
  },

  {
    id = 3355,
    type = "provider",
    provider = "procedures",
    name = "Schema-qualified (dbo.usp_)",
    input = "EXEC dbo.usp_|",
    cursor = { line = 1, col = 14 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"usp_GetEmployeesByDepartment", "usp_UpdateEmployee"}, excludes = {"sp_SearchEmployees"} },
    },
  },

  {
    id = 3356,
    type = "provider",
    provider = "procedures",
    name = "Schema-qualified completion (exec dbo.|)",
    input = "EXEC dbo.|",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"sp_SearchEmployees", "usp_GetEmployeesByDepartment"} },
    },
  },

  {
    id = 3357,
    type = "provider",
    provider = "procedures",
    name = "Case-insensitive matching",
    input = "exec getemp|",
    cursor = { line = 1, col = 12 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"usp_GetEmployeesByDepartment"} },
    },
  },

  {
    id = 3358,
    type = "provider",
    provider = "procedures",
    name = "Multiple schemas available",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"dbo.sp_SearchEmployees", "hr.usp_GetEmployeeInfo"} },
    },
  },

  {
    id = 3359,
    type = "provider",
    provider = "procedures",
    name = "System procedures (sp_help, sp_who)",
    input = "EXEC sp_h|",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"sp_help", "sp_helptext", "sp_helpdb"} },
    },
  },

  {
    id = 3360,
    type = "provider",
    provider = "procedures",
    name = "User procedures only filter",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
      filter = { user_only = true },
    },
    expected = {
      type = "procedure",
      items = { includes = {"usp_GetEmployeesByDepartment"}, excludes = {"sp_help", "sp_who"} },
    },
  },

  {
    id = 3361,
    type = "provider",
    provider = "procedures",
    name = "Function vs procedure distinction",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"sp_SearchEmployees"}, excludes = {"fn_GetEmployeeName", "tvf_GetEmployeeList"} },
    },
  },

  {
    id = 3362,
    type = "provider",
    provider = "procedures",
    name = "After EXEC with parameter",
    input = "EXEC sp_SearchEmployees @name = 'John', @dept|",
    cursor = { line = 1, col = 46 },
    context = {
      mode = "parameter",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
      procedure = "sp_SearchEmployees",
    },
    expected = {
      type = "parameter",
      items = { includes = {"@department", "@departmentId"} },
    },
  },

  {
    id = 3363,
    type = "provider",
    provider = "procedures",
    name = "Nested EXEC in stored proc",
    input = "CREATE PROCEDURE test AS BEGIN\n  EXEC |\nEND",
    cursor = { line = 2, col = 8 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"sp_SearchEmployees", "usp_GetEmployeesByDepartment"} },
    },
  },

  {
    id = 3364,
    type = "provider",
    provider = "procedures",
    name = "EXEC in dynamic SQL",
    input = "DECLARE @sql NVARCHAR(MAX) = 'EXEC |'",
    cursor = { line = 1, col = 35 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"sp_SearchEmployees", "usp_GetEmployeesByDepartment"} },
    },
  },

  {
    id = 3365,
    type = "provider",
    provider = "procedures",
    name = "Cross-database procedure (db.dbo.proc)",
    input = "EXEC OtherDB.dbo.|",
    cursor = { line = 1, col = 18 },
    context = {
      mode = "exec",
      connection = {
        database = "OtherDB",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"sp_GetData", "usp_ProcessOrders"} },
    },
  },

  -- ========================================
  -- Schema-Qualified Procedures (3366-3380)
  -- ========================================

  {
    id = 3366,
    type = "provider",
    provider = "procedures",
    name = "Schema prefix completion (dbo.)",
    input = "EXEC dbo.|",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"sp_SearchEmployees", "usp_GetEmployeesByDepartment"} },
    },
  },

  {
    id = 3367,
    type = "provider",
    provider = "procedures",
    name = "Non-dbo schema (hr.)",
    input = "EXEC hr.|",
    cursor = { line = 1, col = 9 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "hr",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"usp_GetEmployeeInfo", "usp_UpdateBenefits"}, excludes = {"dbo.sp_SearchEmployees"} },
    },
  },

  {
    id = 3368,
    type = "provider",
    provider = "procedures",
    name = "Bracketed schema ([dbo].)",
    input = "EXEC [dbo].|",
    cursor = { line = 1, col = 12 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"sp_SearchEmployees", "usp_GetEmployeesByDepartment"} },
    },
  },

  {
    id = 3369,
    type = "provider",
    provider = "procedures",
    name = "Schema filter only matching",
    input = "EXEC sales.|",
    cursor = { line = 1, col = 12 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "sales",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"usp_ProcessOrder", "usp_CalculateCommission"}, excludes = {"dbo.sp_SearchEmployees", "hr.usp_GetEmployeeInfo"} },
    },
  },

  {
    id = 3370,
    type = "provider",
    provider = "procedures",
    name = "Cross-schema suggestion",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
      suggest_cross_schema = true,
    },
    expected = {
      type = "procedure",
      items = { includes = {"dbo.sp_SearchEmployees", "hr.usp_GetEmployeeInfo", "sales.usp_ProcessOrder"} },
    },
  },

  {
    id = 3371,
    type = "provider",
    provider = "procedures",
    name = "Default schema preference",
    input = "EXEC usp_|",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"usp_GetEmployeesByDepartment"}, priority = { first = "dbo.usp_GetEmployeesByDepartment" } },
    },
  },

  {
    id = 3372,
    type = "provider",
    provider = "procedures",
    name = "Schema with special chars",
    input = "EXEC [User-Schema].|",
    cursor = { line = 1, col = 20 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "User-Schema",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"usp_CustomProc"} },
    },
  },

  {
    id = 3373,
    type = "provider",
    provider = "procedures",
    name = "Three-part name (db.schema.proc)",
    input = "EXEC TestDB.dbo.|",
    cursor = { line = 1, col = 17 },
    context = {
      mode = "exec",
      connection = {
        database = "TestDB",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"sp_GetTestData", "usp_RunTests"} },
    },
  },

  {
    id = 3374,
    type = "provider",
    provider = "procedures",
    name = "Linked server procedure",
    input = "EXEC LinkedServer.RemoteDB.dbo.|",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "exec",
      connection = {
        database = "RemoteDB",
        schema = "dbo",
        server = "LinkedServer",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"sp_RemoteOperation"} },
    },
  },

  {
    id = 3375,
    type = "provider",
    provider = "procedures",
    name = "Schema alias resolution",
    input = "EXEC custom.|",
    cursor = { line = 1, col = 13 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "custom",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"usp_CustomLogic"} },
    },
  },

  {
    id = 3376,
    type = "provider",
    provider = "procedures",
    name = "Mixed case schema",
    input = "EXEC MySchema.|",
    cursor = { line = 1, col = 15 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "MySchema",
      },
    },
    expected = {
      type = "procedure",
      items = { includes = {"usp_MyProc"} },
    },
  },

  {
    id = 3377,
    type = "provider",
    provider = "procedures",
    name = "Schema completion after EXEC",
    input = "EXEC d|",
    cursor = { line = 1, col = 7 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "schema",
      items = { includes = {"dbo", "data"} },
    },
  },

  {
    id = 3378,
    type = "provider",
    provider = "procedures",
    name = "Schema completion after EXECUTE",
    input = "EXECUTE s|",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "schema",
      items = { includes = {"sales", "support"} },
    },
  },

  {
    id = 3379,
    type = "provider",
    provider = "procedures",
    name = "All schemas listing",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
      show_all_schemas = true,
    },
    expected = {
      type = "procedure",
      items = { includes = {"dbo.sp_SearchEmployees", "hr.usp_GetEmployeeInfo", "sales.usp_ProcessOrder", "custom.usp_CustomLogic"} },
    },
  },

  {
    id = 3380,
    type = "provider",
    provider = "procedures",
    name = "Schema metadata display",
    input = "EXEC dbo.|",
    cursor = { line = 1, col = 10 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"sp_SearchEmployees"},
        metadata = {
          sp_SearchEmployees = { schema = "dbo", type = "procedure" }
        }
      },
    },
  },

  -- ========================================
  -- Procedure Metadata (3381-3395)
  -- ========================================

  {
    id = 3381,
    type = "provider",
    provider = "procedures",
    name = "Parameter count in detail",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"sp_SearchEmployees"},
        metadata = {
          sp_SearchEmployees = { param_count = 3, detail = "(3 params)" }
        }
      },
    },
  },

  {
    id = 3382,
    type = "provider",
    provider = "procedures",
    name = "Return type indication",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"sp_SearchEmployees"},
        metadata = {
          sp_SearchEmployees = { returns = "result_set", detail = "Returns result set" }
        }
      },
    },
  },

  {
    id = 3383,
    type = "provider",
    provider = "procedures",
    name = "Procedure documentation",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"sp_SearchEmployees"},
        metadata = {
          sp_SearchEmployees = { documentation = "Searches employees by name and department" }
        }
      },
    },
  },

  {
    id = 3384,
    type = "provider",
    provider = "procedures",
    name = "Input parameters shown",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"sp_SearchEmployees"},
        metadata = {
          sp_SearchEmployees = { parameters = {"@name", "@department", "@minSalary"} }
        }
      },
    },
  },

  {
    id = 3385,
    type = "provider",
    provider = "procedures",
    name = "Output parameters indicated",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"usp_GetEmployeeCount"},
        metadata = {
          usp_GetEmployeeCount = { parameters = {"@department IN", "@count OUT"} }
        }
      },
    },
  },

  {
    id = 3386,
    type = "provider",
    provider = "procedures",
    name = "Default parameter values",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"sp_SearchEmployees"},
        metadata = {
          sp_SearchEmployees = { parameters = {"@name = NULL", "@department = 'All'", "@minSalary = 0"} }
        }
      },
    },
  },

  {
    id = 3387,
    type = "provider",
    provider = "procedures",
    name = "Required vs optional params",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"usp_ProcessOrder"},
        metadata = {
          usp_ProcessOrder = {
            parameters = {"@orderId [required]", "@status = 'pending'", "@notes = NULL"}
          }
        }
      },
    },
  },

  {
    id = 3388,
    type = "provider",
    provider = "procedures",
    name = "Procedure creation date",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"sp_SearchEmployees"},
        metadata = {
          sp_SearchEmployees = { created = "2024-01-15" }
        }
      },
    },
  },

  {
    id = 3389,
    type = "provider",
    provider = "procedures",
    name = "Procedure owner",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"sp_SearchEmployees"},
        metadata = {
          sp_SearchEmployees = { owner = "dbo", schema = "dbo" }
        }
      },
    },
  },

  {
    id = 3390,
    type = "provider",
    provider = "procedures",
    name = "Recently used priority",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
      usage_tracking = true,
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"sp_SearchEmployees", "usp_GetEmployeesByDepartment"},
        priority = { first = "sp_SearchEmployees" } -- Most recently used
      },
    },
  },

  {
    id = 3391,
    type = "provider",
    provider = "procedures",
    name = "Extended properties",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"sp_SearchEmployees"},
        metadata = {
          sp_SearchEmployees = {
            extended_properties = {
              Description = "Search employees by various criteria",
              Version = "1.2"
            }
          }
        }
      },
    },
  },

  {
    id = 3392,
    type = "provider",
    provider = "procedures",
    name = "Encrypted procedure handling",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"sp_SecureOperation"},
        metadata = {
          sp_SecureOperation = { encrypted = true, detail = "Encrypted procedure" }
        }
      },
    },
  },

  {
    id = 3393,
    type = "provider",
    provider = "procedures",
    name = "CLR procedure indication",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"clr_ProcessData"},
        metadata = {
          clr_ProcessData = { is_clr = true, detail = "CLR procedure" }
        }
      },
    },
  },

  {
    id = 3394,
    type = "provider",
    provider = "procedures",
    name = "Scalar function distinct from proc",
    input = "SELECT |",
    cursor = { line = 1, col = 8 },
    context = {
      mode = "select_function",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "function",
      items = { includes = {"fn_GetEmployeeName"}, excludes = {"sp_SearchEmployees"} },
    },
  },

  {
    id = 3395,
    type = "provider",
    provider = "procedures",
    name = "Table-valued function distinct",
    input = "SELECT * FROM |",
    cursor = { line = 1, col = 15 },
    context = {
      mode = "from_function",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "function",
      items = { includes = {"tvf_GetEmployeeList"}, excludes = {"sp_SearchEmployees", "fn_GetEmployeeName"} },
    },
  },

  -- ========================================
  -- Edge Cases (3396-3400)
  -- ========================================

  {
    id = 3396,
    type = "provider",
    provider = "procedures",
    name = "No procedures in database",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "empty_db",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = { count = 0 },
    },
  },

  {
    id = 3397,
    type = "provider",
    provider = "procedures",
    name = "Very long procedure name",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"usp_VeryLongProcedureNameThatExceedsNormalLengthButIsStillValid"}
      },
    },
  },

  {
    id = 3398,
    type = "provider",
    provider = "procedures",
    name = "Procedure with reserved word name",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"[Select]", "[Table]", "[User]"}
      },
    },
  },

  {
    id = 3399,
    type = "provider",
    provider = "procedures",
    name = "Procedure starting with number",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"usp_2024ProcessData", "[3rdPartyImport]"}
      },
    },
  },

  {
    id = 3400,
    type = "provider",
    provider = "procedures",
    name = "Unicode procedure name",
    input = "EXEC |",
    cursor = { line = 1, col = 6 },
    context = {
      mode = "exec",
      connection = {
        database = "vim_dadbod_test",
        schema = "dbo",
      },
    },
    expected = {
      type = "procedure",
      items = {
        includes = {"usp_処理データ", "sp_Αναζήτηση"}
      },
    },
  },
}
