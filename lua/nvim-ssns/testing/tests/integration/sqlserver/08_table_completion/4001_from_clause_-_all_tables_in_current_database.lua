-- Test 4001: FROM clause - all tables in current database

return {
  number = 4001,
  description = "FROM clause - all tables in current database",
  database = "vim_dadbod_test",
  query = "SELECT * FROM █",
  expected = {
    items = {
      excludes = {
        "usp_GetEmployeesByDepartment",
        "usp_InsertEmployee",
        "fn_CalculateYearsOfService",
        "fn_GetEmployeeFullName",
      },
      includes = {
        "TEST",
        "Branch_Prod",
        "vim_dadbod_test",
        "dbo",
        "hr",
        "Regions",
        "Countries",
        "Departments",
        "Employees",
        "Customers",
        "Orders",
        "Products",
        "Projects",
        "vw_ActiveEmployees",
        "vw_DepartmentSummary",
        "vw_ProjectStatus",
        "syn_ActiveEmployees",
        "syn_Depts",
        "syn_Employees",
        "syn_HRBenefits",
        "fn_GetEmployeesBySalaryRange",
        "GetCustomerOrders",
        "Benefits",
      },
    },
    type = "table",
  },
}
