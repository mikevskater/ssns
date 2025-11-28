return {
  number = 1,
  description = [[Autocomplete for tables in schema]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM dbo.]],
  cursor = {
    line = 0,
    col = 18
  },
  expected = {
    type = [[table]],
    items = {
      includes = {
        -- Sample of tables from dbo schema
        "Departments",
        "Employees",
        "Projects",
        "Customers",
        "Orders",
        "Products",
        "Categories",
        "Suppliers",
        -- Sample of views from dbo schema
        "vw_ActiveEmployees",
        "vw_DepartmentSummary",
        "vw_ProjectStatus",
        "CustomerOrders",
        "View_CustomerOrders",
        -- Sample of synonyms from dbo schema
        "syn_ActiveEmployees",
        "syn_Depts",
        "syn_Employees",
        "syn_HRBenefits",
        -- Table-valued functions from dbo schema (can be queried)
        "fn_GetEmployeesBySalaryRange",
        "GetCustomerOrders",
        "GetOrderTotal"
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