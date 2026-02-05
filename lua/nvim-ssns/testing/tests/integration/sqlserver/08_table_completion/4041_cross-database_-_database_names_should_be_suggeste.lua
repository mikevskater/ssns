-- Test 4041: Cross-database - database names should be suggested

return {
  number = 4041,
  description = "Cross-database - database names should be suggested",
  database = "vim_dadbod_test",
  query = "SELECT * FROM █",
  expected = {
    items = {
      includes = {
        "vim_dadbod_test",
        "TEST",
        "Branch_Prod",
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
    type = "object",
  },
}
