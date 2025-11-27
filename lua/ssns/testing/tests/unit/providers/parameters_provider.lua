-- Test file: parameters_provider.lua
-- IDs: 3401-3450
-- Tests: Parameter completion for stored procedure calls
--
-- Test categories:
-- - 3401-3415: Positional parameters
-- - 3416-3430: Named parameters
-- - 3431-3445: Parameter type hints
-- - 3446-3450: Edge cases

return {
  -- =============================================================================
  -- Positional Parameters (3401-3415) - 15 tests
  -- =============================================================================

  {
    id = 3401,
    type = "provider",
    provider = "parameters",
    name = "First parameter suggestion",
    input = "EXEC sp_SearchEmployees |",
    cursor = { line = 1, col = 25 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      parameter_position = 0,
    },
    expected = {
      type = "parameter",
      items = { includes = { "@SearchTerm" } },
    },
  },

  {
    id = 3402,
    type = "provider",
    provider = "parameters",
    name = "Second parameter after comma",
    input = "EXEC sp_SearchEmployees 'John', |",
    cursor = { line = 1, col = 33 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      parameter_position = 1,
    },
    expected = {
      type = "parameter",
      items = { includes = { "@DepartmentID" } },
    },
  },

  {
    id = 3403,
    type = "provider",
    provider = "parameters",
    name = "Third parameter suggestion",
    input = "EXEC sp_SearchEmployees 'John', 10, |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      parameter_position = 2,
    },
    expected = {
      type = "parameter",
      items = { includes = { "@IncludeInactive" } },
    },
  },

  {
    id = 3404,
    type = "provider",
    provider = "parameters",
    name = "No more parameters (complete)",
    input = "EXEC sp_SearchEmployees 'John', 10, 0|",
    cursor = { line = 1, col = 39 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      parameter_position = 3,
    },
    expected = {
      type = "parameter",
      items = { count = 0 },
    },
  },

  {
    id = 3405,
    type = "provider",
    provider = "parameters",
    name = "Required parameter indication",
    input = "EXEC sp_UpdateEmployee |",
    cursor = { line = 1, col = 24 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_UpdateEmployee",
      parameter_position = 0,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@EmployeeID" },
        item_properties = {
          ["@EmployeeID"] = {
            labelDetails = { description = "required" },
          },
        },
      },
    },
  },

  {
    id = 3406,
    type = "provider",
    provider = "parameters",
    name = "Optional parameter indication",
    input = "EXEC sp_SearchEmployees 'John', |",
    cursor = { line = 1, col = 33 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      parameter_position = 1,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@DepartmentID" },
        item_properties = {
          ["@DepartmentID"] = {
            labelDetails = { description = "optional" },
          },
        },
      },
    },
  },

  {
    id = 3407,
    type = "provider",
    provider = "parameters",
    name = "Parameter with default value",
    input = "EXEC sp_GetRecentOrders |",
    cursor = { line = 1, col = 25 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_GetRecentOrders",
      parameter_position = 0,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@DaysBack" },
        item_properties = {
          ["@DaysBack"] = {
            labelDetails = { description = "default: 30" },
          },
        },
      },
    },
  },

  {
    id = 3408,
    type = "provider",
    provider = "parameters",
    name = "Multiple required params",
    input = "EXEC sp_CreateOrder |",
    cursor = { line = 1, col = 21 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_CreateOrder",
      parameter_position = 0,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@CustomerID", "@ProductID", "@Quantity" },
        all_required = true,
      },
    },
  },

  {
    id = 3409,
    type = "provider",
    provider = "parameters",
    name = "Mixed required/optional",
    input = "EXEC sp_GetEmployeeDetails 100, |",
    cursor = { line = 1, col = 33 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_GetEmployeeDetails",
      parameter_position = 1,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@IncludeSalary" },
        item_properties = {
          ["@IncludeSalary"] = {
            labelDetails = { description = "optional, default: 0" },
          },
        },
      },
    },
  },

  {
    id = 3410,
    type = "provider",
    provider = "parameters",
    name = "Output parameter suggestion",
    input = "EXEC sp_GetEmployeeCount |",
    cursor = { line = 1, col = 26 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_GetEmployeeCount",
      parameter_position = 0,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@TotalCount" },
        item_properties = {
          ["@TotalCount"] = {
            labelDetails = { description = "OUTPUT" },
          },
        },
      },
    },
  },

  {
    id = 3411,
    type = "provider",
    provider = "parameters",
    name = "Parameter position tracking",
    input = "EXEC sp_ComplexProc 1, 'test', |",
    cursor = { line = 1, col = 33 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_ComplexProc",
      parameter_position = 2,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@ThirdParam" },
        excludes = { "@FirstParam", "@SecondParam" },
      },
    },
  },

  {
    id = 3412,
    type = "provider",
    provider = "parameters",
    name = "After value, next param",
    input = "EXEC sp_SearchEmployees 'John'|",
    cursor = { line = 1, col = 31 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      parameter_position = 1,
      suggest_comma = true,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@DepartmentID" },
      },
    },
  },

  {
    id = 3413,
    type = "provider",
    provider = "parameters",
    name = "Procedure with no params",
    input = "EXEC sp_RefreshCache |",
    cursor = { line = 1, col = 22 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_RefreshCache",
      parameter_position = 0,
    },
    expected = {
      type = "parameter",
      items = { count = 0 },
    },
  },

  {
    id = 3414,
    type = "provider",
    provider = "parameters",
    name = "Many parameters (10+)",
    input = "EXEC sp_ComplexReport 2024, 1, |",
    cursor = { line = 1, col = 33 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_ComplexReport",
      parameter_position = 2,
    },
    expected = {
      type = "parameter",
      items = {
        min_count = 8,
        includes = { "@EndMonth" },
      },
    },
  },

  {
    id = 3415,
    type = "provider",
    provider = "parameters",
    name = "Parameter after expression",
    input = "EXEC sp_SearchEmployees CONCAT('Jo', 'hn'), |",
    cursor = { line = 1, col = 46 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      parameter_position = 1,
    },
    expected = {
      type = "parameter",
      items = { includes = { "@DepartmentID" } },
    },
  },

  -- =============================================================================
  -- Named Parameters (3416-3430) - 15 tests
  -- =============================================================================

  {
    id = 3416,
    type = "provider",
    provider = "parameters",
    name = "Named parameter (@Param =)",
    input = "EXEC sp_SearchEmployees @|",
    cursor = { line = 1, col = 26 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      named_parameter_mode = true,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@SearchTerm", "@DepartmentID", "@IncludeInactive" },
      },
    },
  },

  {
    id = 3417,
    type = "provider",
    provider = "parameters",
    name = "Named parameter completion after @",
    input = "EXEC sp_SearchEmployees @Search|",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      named_parameter_mode = true,
      partial_param = "@Search",
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@SearchTerm" },
        excludes = { "@DepartmentID" },
      },
    },
  },

  {
    id = 3418,
    type = "provider",
    provider = "parameters",
    name = "Named param partial (@Search)",
    input = "EXEC sp_SearchEmployees @Sear|",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      named_parameter_mode = true,
      partial_param = "@Sear",
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@SearchTerm" },
      },
    },
  },

  {
    id = 3419,
    type = "provider",
    provider = "parameters",
    name = "Named params unordered",
    input = "EXEC sp_SearchEmployees @DepartmentID = 10, @|",
    cursor = { line = 1, col = 47 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      named_parameter_mode = true,
      used_parameters = { "@DepartmentID" },
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@SearchTerm", "@IncludeInactive" },
        excludes = { "@DepartmentID" },
      },
    },
  },

  {
    id = 3420,
    type = "provider",
    provider = "parameters",
    name = "Mixed named/positional",
    input = "EXEC sp_SearchEmployees 'John', @|",
    cursor = { line = 1, col = 35 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      named_parameter_mode = true,
      parameter_position = 1,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@DepartmentID", "@IncludeInactive" },
        excludes = { "@SearchTerm" },
      },
    },
  },

  {
    id = 3421,
    type = "provider",
    provider = "parameters",
    name = "All remaining named params",
    input = "EXEC sp_UpdateEmployee @EmployeeID = 100, @|",
    cursor = { line = 1, col = 45 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_UpdateEmployee",
      named_parameter_mode = true,
      used_parameters = { "@EmployeeID" },
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@FirstName", "@LastName", "@Email" },
        excludes = { "@EmployeeID" },
      },
    },
  },

  {
    id = 3422,
    type = "provider",
    provider = "parameters",
    name = "Already-specified param exclusion",
    input = "EXEC sp_SearchEmployees @SearchTerm = 'John', @SearchTerm = |",
    cursor = { line = 1, col = 61 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      named_parameter_mode = true,
      duplicate_warning = "@SearchTerm",
    },
    expected = {
      type = "parameter",
      items = { count = 0 },
      warning = "Parameter @SearchTerm already specified",
    },
  },

  {
    id = 3423,
    type = "provider",
    provider = "parameters",
    name = "Named OUTPUT parameter",
    input = "EXEC sp_GetEmployeeCount @|",
    cursor = { line = 1, col = 27 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_GetEmployeeCount",
      named_parameter_mode = true,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@TotalCount" },
        item_properties = {
          ["@TotalCount"] = {
            labelDetails = { description = "OUTPUT" },
            insertText = "@TotalCount = @MyVar OUTPUT",
          },
        },
      },
    },
  },

  {
    id = 3424,
    type = "provider",
    provider = "parameters",
    name = "Named param with default",
    input = "EXEC sp_GetRecentOrders @|",
    cursor = { line = 1, col = 26 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_GetRecentOrders",
      named_parameter_mode = true,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@DaysBack" },
        item_properties = {
          ["@DaysBack"] = {
            labelDetails = { description = "default: 30" },
          },
        },
      },
    },
  },

  {
    id = 3425,
    type = "provider",
    provider = "parameters",
    name = "Case-insensitive param names",
    input = "EXEC sp_SearchEmployees @searcht|",
    cursor = { line = 1, col = 33 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      named_parameter_mode = true,
      partial_param = "@searcht",
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@SearchTerm" },
      },
    },
  },

  {
    id = 3426,
    type = "provider",
    provider = "parameters",
    name = "Named param value hint",
    input = "EXEC sp_SearchEmployees @SearchTerm = |",
    cursor = { line = 1, col = 40 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      parameter_name = "@SearchTerm",
    },
    expected = {
      type = "value",
      items = {
        includes = { "''", "NULL" },
      },
    },
  },

  {
    id = 3427,
    type = "provider",
    provider = "parameters",
    name = "Named param after positional",
    input = "EXEC sp_SearchEmployees 'John', 10, @|",
    cursor = { line = 1, col = 39 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      named_parameter_mode = true,
      parameter_position = 2,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@IncludeInactive" },
        excludes = { "@SearchTerm", "@DepartmentID" },
      },
    },
  },

  {
    id = 3428,
    type = "provider",
    provider = "parameters",
    name = "All params named style",
    input = "EXEC sp_SearchEmployees @SearchTerm = 'John', @DepartmentID = 10, @|",
    cursor = { line = 1, col = 69 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      named_parameter_mode = true,
      used_parameters = { "@SearchTerm", "@DepartmentID" },
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@IncludeInactive" },
        excludes = { "@SearchTerm", "@DepartmentID" },
      },
    },
  },

  {
    id = 3429,
    type = "provider",
    provider = "parameters",
    name = "Named param documentation",
    input = "EXEC sp_SearchEmployees @|",
    cursor = { line = 1, col = 26 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      named_parameter_mode = true,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@SearchTerm" },
        item_properties = {
          ["@SearchTerm"] = {
            documentation = "Search term for employee name (NVARCHAR(100))",
          },
        },
      },
    },
  },

  {
    id = 3430,
    type = "provider",
    provider = "parameters",
    name = "Named param type hint",
    input = "EXEC sp_UpdateEmployee @EmployeeID = |",
    cursor = { line = 1, col = 39 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_UpdateEmployee",
      parameter_name = "@EmployeeID",
      parameter_type = "INT",
    },
    expected = {
      type = "value",
      items = {
        includes = { "NULL" },
        excludes = { "''" },
      },
    },
  },

  -- =============================================================================
  -- Parameter Type Hints (3431-3445) - 15 tests
  -- =============================================================================

  {
    id = 3431,
    type = "provider",
    provider = "parameters",
    name = "INT parameter hint",
    input = "EXEC sp_UpdateEmployee @EmployeeID = |",
    cursor = { line = 1, col = 39 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_UpdateEmployee",
      parameter_name = "@EmployeeID",
      parameter_type = "INT",
    },
    expected = {
      type = "value",
      items = {
        includes = { "0", "NULL" },
        type_hint = "INT",
      },
    },
  },

  {
    id = 3432,
    type = "provider",
    provider = "parameters",
    name = "VARCHAR parameter hint",
    input = "EXEC sp_SearchEmployees @SearchTerm = |",
    cursor = { line = 1, col = 40 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      parameter_name = "@SearchTerm",
      parameter_type = "NVARCHAR(100)",
    },
    expected = {
      type = "value",
      items = {
        includes = { "''", "NULL" },
        type_hint = "NVARCHAR(100)",
      },
    },
  },

  {
    id = 3433,
    type = "provider",
    provider = "parameters",
    name = "DATE parameter hint",
    input = "EXEC sp_GetOrdersByDate @OrderDate = |",
    cursor = { line = 1, col = 39 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_GetOrdersByDate",
      parameter_name = "@OrderDate",
      parameter_type = "DATE",
    },
    expected = {
      type = "value",
      items = {
        includes = { "'YYYY-MM-DD'", "GETDATE()", "NULL" },
        type_hint = "DATE",
      },
    },
  },

  {
    id = 3434,
    type = "provider",
    provider = "parameters",
    name = "DECIMAL parameter hint",
    input = "EXEC sp_UpdatePrice @Price = |",
    cursor = { line = 1, col = 30 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_UpdatePrice",
      parameter_name = "@Price",
      parameter_type = "DECIMAL(18,2)",
    },
    expected = {
      type = "value",
      items = {
        includes = { "0.00", "NULL" },
        type_hint = "DECIMAL(18,2)",
      },
    },
  },

  {
    id = 3435,
    type = "provider",
    provider = "parameters",
    name = "BIT/boolean parameter",
    input = "EXEC sp_SearchEmployees @SearchTerm = 'John', @IncludeInactive = |",
    cursor = { line = 1, col = 67 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      parameter_name = "@IncludeInactive",
      parameter_type = "BIT",
    },
    expected = {
      type = "value",
      items = {
        includes = { "0", "1", "NULL" },
        type_hint = "BIT",
      },
    },
  },

  {
    id = 3436,
    type = "provider",
    provider = "parameters",
    name = "NULL suggestion for nullable",
    input = "EXEC sp_UpdateEmployee @MiddleName = |",
    cursor = { line = 1, col = 39 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_UpdateEmployee",
      parameter_name = "@MiddleName",
      parameter_type = "NVARCHAR(50)",
      nullable = true,
    },
    expected = {
      type = "value",
      items = {
        includes = { "NULL", "''" },
      },
    },
  },

  {
    id = 3437,
    type = "provider",
    provider = "parameters",
    name = "DEFAULT keyword suggestion",
    input = "EXEC sp_GetRecentOrders @DaysBack = |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_GetRecentOrders",
      parameter_name = "@DaysBack",
      parameter_type = "INT",
      has_default = true,
      default_value = "30",
    },
    expected = {
      type = "value",
      items = {
        includes = { "DEFAULT", "30", "NULL" },
      },
    },
  },

  {
    id = 3438,
    type = "provider",
    provider = "parameters",
    name = "Type-appropriate literals",
    input = "EXEC sp_UpdateEmployee @Salary = |",
    cursor = { line = 1, col = 34 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_UpdateEmployee",
      parameter_name = "@Salary",
      parameter_type = "MONEY",
    },
    expected = {
      type = "value",
      items = {
        includes = { "0.00", "NULL" },
        excludes = { "''" },
      },
    },
  },

  {
    id = 3439,
    type = "provider",
    provider = "parameters",
    name = "String quote suggestion",
    input = "EXEC sp_SearchEmployees @SearchTerm = |",
    cursor = { line = 1, col = 40 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SearchEmployees",
      parameter_name = "@SearchTerm",
      parameter_type = "NVARCHAR(100)",
    },
    expected = {
      type = "value",
      items = {
        includes = { "''" },
        item_properties = {
          ["''"] = {
            insertText = "'$1'",
            insertTextFormat = 2, -- Snippet
          },
        },
      },
    },
  },

  {
    id = 3440,
    type = "provider",
    provider = "parameters",
    name = "Date format suggestion",
    input = "EXEC sp_GetOrdersByDate @StartDate = |",
    cursor = { line = 1, col = 39 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_GetOrdersByDate",
      parameter_name = "@StartDate",
      parameter_type = "DATETIME",
    },
    expected = {
      type = "value",
      items = {
        includes = { "'YYYY-MM-DD HH:MM:SS'", "GETDATE()", "NULL" },
      },
    },
  },

  {
    id = 3441,
    type = "provider",
    provider = "parameters",
    name = "Numeric format hint",
    input = "EXEC sp_CalculateTotal @TaxRate = |",
    cursor = { line = 1, col = 36 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_CalculateTotal",
      parameter_name = "@TaxRate",
      parameter_type = "DECIMAL(5,4)",
    },
    expected = {
      type = "value",
      items = {
        includes = { "0.0000", "NULL" },
        type_hint = "DECIMAL(5,4)",
      },
    },
  },

  {
    id = 3442,
    type = "provider",
    provider = "parameters",
    name = "Table-valued param hint",
    input = "EXEC sp_BulkInsert @Items = |",
    cursor = { line = 1, col = 29 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_BulkInsert",
      parameter_name = "@Items",
      parameter_type = "ItemTableType",
      is_table_valued = true,
    },
    expected = {
      type = "value",
      items = {
        includes = { "@MyTableVar" },
        type_hint = "Table-valued: ItemTableType",
      },
    },
  },

  {
    id = 3443,
    type = "provider",
    provider = "parameters",
    name = "XML parameter hint",
    input = "EXEC sp_ProcessXml @XmlData = |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_ProcessXml",
      parameter_name = "@XmlData",
      parameter_type = "XML",
    },
    expected = {
      type = "value",
      items = {
        includes = { "'<root></root>'", "NULL" },
        type_hint = "XML",
      },
    },
  },

  {
    id = 3444,
    type = "provider",
    provider = "parameters",
    name = "JSON parameter hint",
    input = "EXEC sp_ProcessJson @JsonData = |",
    cursor = { line = 1, col = 33 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_ProcessJson",
      parameter_name = "@JsonData",
      parameter_type = "NVARCHAR(MAX)",
      is_json = true,
    },
    expected = {
      type = "value",
      items = {
        includes = { "'{}'", "NULL" },
        type_hint = "JSON (NVARCHAR(MAX))",
      },
    },
  },

  {
    id = 3445,
    type = "provider",
    provider = "parameters",
    name = "Binary parameter hint",
    input = "EXEC sp_ProcessBinary @BinaryData = |",
    cursor = { line = 1, col = 38 },
    context = {
      mode = "parameter_value",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_ProcessBinary",
      parameter_name = "@BinaryData",
      parameter_type = "VARBINARY(MAX)",
    },
    expected = {
      type = "value",
      items = {
        includes = { "0x", "NULL" },
        type_hint = "VARBINARY(MAX)",
      },
    },
  },

  -- =============================================================================
  -- Edge Cases (3446-3450) - 5 tests
  -- =============================================================================

  {
    id = 3446,
    type = "provider",
    provider = "parameters",
    name = "No procedure context",
    input = "SELECT * FROM Employees WHERE |",
    cursor = { line = 1, col = 32 },
    context = {
      mode = "unknown",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
    },
    expected = {
      type = "parameter",
      items = { count = 0 },
    },
  },

  {
    id = 3447,
    type = "provider",
    provider = "parameters",
    name = "Unknown procedure",
    input = "EXEC sp_NonExistentProc |",
    cursor = { line = 1, col = 25 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_NonExistentProc",
      parameter_position = 0,
    },
    expected = {
      type = "parameter",
      items = { count = 0 },
      error = "Procedure not found",
    },
  },

  {
    id = 3448,
    type = "provider",
    provider = "parameters",
    name = "Procedure with cursor param",
    input = "EXEC sp_GetCursorData @|",
    cursor = { line = 1, col = 24 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_GetCursorData",
      named_parameter_mode = true,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@ResultCursor" },
        item_properties = {
          ["@ResultCursor"] = {
            labelDetails = { description = "CURSOR VARYING OUTPUT" },
          },
        },
      },
    },
  },

  {
    id = 3449,
    type = "provider",
    provider = "parameters",
    name = "Very long parameter name",
    input = "EXEC sp_WithLongParams @|",
    cursor = { line = 1, col = 25 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_WithLongParams",
      named_parameter_mode = true,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@VeryLongParameterNameThatExceedsNormalLength" },
        item_properties = {
          ["@VeryLongParameterNameThatExceedsNormalLength"] = {
            label = "@VeryLongParameterNameThatExceedsNormalLength",
            labelDetails = { description = "NVARCHAR(100)" },
          },
        },
      },
    },
  },

  {
    id = 3450,
    type = "provider",
    provider = "parameters",
    name = "Parameter with special characters",
    input = "EXEC sp_SpecialParams @|",
    cursor = { line = 1, col = 24 },
    context = {
      mode = "parameter",
      connection = { database = "vim_dadbod_test", schema = "dbo" },
      procedure_name = "sp_SpecialParams",
      named_parameter_mode = true,
    },
    expected = {
      type = "parameter",
      items = {
        includes = { "@Param_With_Underscores", "@Param123", "@ParamWithNumbers456" },
      },
    },
  },
}
