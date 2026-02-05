return {
  number = 2,
  description = [[Autocomplete for tables in schema]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM hr.█]],
  expected = {
    type = [[table]],
    items = {
      includes = {
        "Benefits" -- hr.Benefits table (only table in hr schema)
        -- Note: hr.fn_GetTotalBenefitCost is a scalar function and should NOT appear
        -- in SELECT completion (scalar functions cannot be queried directly)
      },
      excludes = {
        -- Tables from dbo schema should not appear
        "Employees",
        "Departments",
        "Projects",
        "Customers",
        "Orders",
        "Products",
        "Categories",
        "Suppliers",
        -- Views from dbo schema
        "vw_ActiveEmployees",
        "vw_DepartmentSummary",
        "vw_ProjectStatus",
        -- Synonyms from dbo schema
        "syn_Employees",
        "syn_Depts",
        "syn_HRBenefits", -- This is a synonym in dbo pointing to hr.Benefits
        "syn_ActiveEmployees",
        -- Synonyms from Branch schema
        "AllDivisions",
        "CentralDivision",
        "DivisionMetrics",
        "EasternDivision",
        "WesternDivision",
        -- Scalar functions should not appear (not selectable)
        "fn_GetTotalBenefitCost", -- hr schema scalar function
        "fn_GetEmployeeFullName", -- dbo schema scalar function
        "fn_CalculateYearsOfService", -- dbo schema scalar function
        -- Table-valued functions from dbo should not appear in hr completion
        "fn_GetEmployeesBySalaryRange",
        "GetCustomerOrders",
        "GetOrderTotal",
        -- Stored procedures should not appear
        "usp_GetEmployeesByDepartment",
        "sp_SearchEmployees"
      }
    }
  }
}