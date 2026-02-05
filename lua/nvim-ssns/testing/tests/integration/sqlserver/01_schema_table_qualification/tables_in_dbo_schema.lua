return {
  number = 1,
  description = [[Autocomplete for tables in schema]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM dbo.█]],
  expected = {
    type = [[table]],
    items = {
      includes = {
        -- Tables from dbo schema (8 total)
        "Regions",
        "Countries",
        "Departments",
        "Employees",
        "Customers",
        "Orders",
        "Products",
        "Projects",
        -- Views from dbo schema (3 total)
        "vw_ActiveEmployees",
        "vw_DepartmentSummary",
        "vw_ProjectStatus",
        -- Synonyms from dbo schema (4 total)
        "syn_ActiveEmployees",
        "syn_Depts",
        "syn_Employees",
        "syn_HRBenefits",
        -- Table-valued functions from dbo schema (2 total)
        "fn_GetEmployeesBySalaryRange",
        "GetCustomerOrders"
      },
      excludes = {
        -- Tables from other schemas should not appear
        "Benefits", -- hr schema table
        -- Synonyms in Branch schema should not appear
        "AllDivisions",
        "CentralDivision",
        "DivisionMetrics",
        "EasternDivision",
        "WesternDivision",
        -- Objects from other databases
        "Records", -- TEST.dbo.Records
        "central_division", -- Branch_Prod.dbo
        "division_metrics", -- Branch_Prod.dbo
        "eastern_division", -- Branch_Prod.dbo
        "western_division", -- Branch_Prod.dbo
        -- Scalar functions should not appear (not selectable)
        "fn_GetEmployeeFullName",
        "fn_CalculateYearsOfService",
        "fn_GetEmployeesByDepartment",
        "fn_GetTotalBenefitCost", -- hr schema function
        -- Stored procedures should not appear (not selectable)
        "usp_GetEmployeesByDepartment",
        "sp_SearchEmployees",
        "usp_InsertEmployee",
        "usp_UpdateEmployeeSalary"
      }
    }
  }
}