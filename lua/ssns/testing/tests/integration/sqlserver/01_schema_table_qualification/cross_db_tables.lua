return {
  number = 5,
  description = [[Autocomplete for tables in schemas in different database (cross-db handling)]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM TEST.dbo.]],
  cursor = {
    line = 0,
    col = 23
  },
  expected = {
    type = [[table]],
    items = {
      includes = {
        "Records", -- TEST.dbo table
        "syn_MainEmployees" -- TEST.dbo synonym
      },
      excludes = {
        -- Tables from vim_dadbod_test.dbo should not appear
        "Employees",
        "Departments",
        "Customers",
        "Orders",
        "Products",
        -- Tables from vim_dadbod_test.hr should not appear
        "Benefits",
        -- Tables from Branch_Prod should not appear
        "central_division",
        "eastern_division",
        "western_division",
        "division_metrics",
        -- Views from other databases should not appear
        "vw_ActiveEmployees",
        "vw_all_divisions",
        -- Synonyms from vim_dadbod_test should not appear
        "syn_Employees",
        "syn_Depts",
        "AllDivisions",
        "CentralDivision",
        -- Scalar functions should not appear (not selectable)
        "fn_GetEmployeeFullName",
        "fn_CalculateYearsOfService",
        -- Stored procedures should not appear (not selectable)
        "usp_GetEmployeesByDepartment",
        "sp_SearchEmployees"
      }
    }
  }
}