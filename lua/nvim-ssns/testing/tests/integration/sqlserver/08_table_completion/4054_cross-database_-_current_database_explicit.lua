-- Test 4054: Cross-database - current database explicit

return {
  number = 4054,
  description = "Cross-database - current database explicit",
  database = "vim_dadbod_test",
  query = "SELECT * FROM vim_dadbod_test.dbo.█",
  expected = {
    items = {
      includes = {
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
      },
    },
    type = "table",
  },
}
