return {
  number = 10,
  description = [[Autocomplete for Tables/Views in FROM clause]],
  database = [[vim_dadbod_test]],
  query = [[SELECT * FROM █]],
  expected = {
    type = [[table]],
    items = {
      includes = {
      -- Databases (3 total)
      "Branch_Prod",
      "TEST",

      -- Schemas in vim_dadbod_test (2 total)
      "dbo",
      "hr",

      -- dbo schema tables (8 total)
      "Countries",
      "Customers",
      "Departments",
      "Employees",
      "Orders",
      "Products",
      "Projects",
      "Regions",

        -- hr schema table
        "Benefits",

        -- dbo views (FROM-selectable)
        "vw_ActiveEmployees",
        "vw_DepartmentSummary",
        "vw_ProjectStatus",

        -- dbo table-valued functions (can be used in FROM)
        "GetCustomerOrders",

        -- dbo synonyms (FROM-selectable)
        "syn_ActiveEmployees",
        "syn_Depts",
        "syn_Employees",
        "syn_HRBenefits",
      },
      excludes = {
        -- Should NOT include procedures
        "usp_GetEmployeesByDepartment",
        "usp_InsertEmployee",
      },
    },
  },
}