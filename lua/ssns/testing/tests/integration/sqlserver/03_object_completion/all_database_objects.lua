return {
  number = 10,
  description = [[Autocomplete for Objects in database]],
  database = [[vim_dadbod_test]],
  query = [[SELECT
 *
FROM]],
  cursor = {
    line = 3,
    col = 4
  },
  expected = {
    type = [[object]],
    items = {
      -- Databases (3 total)
      "Branch_Prod",
      "TEST",

      -- Schemas in vim_dadbod_test (2 total)
      "dbo",
      "hr",

      -- dbo schema tables (8 total)
      "[dbo].[Countries]",
      "[dbo].[Customers]",
      "[dbo].[Departments]",
      "[dbo].[Employees]",
      "[dbo].[Orders]",
      "[dbo].[Products]",
      "[dbo].[Projects]",
      "[dbo].[Regions]",

      -- hr schema table (1 total)
      "[hr].[Benefits]",

      -- dbo views (3 total - FROM-selectable)
      "[dbo].[vw_ActiveEmployees]",
      "[dbo].[vw_DepartmentSummary]",
      "[dbo].[vw_ProjectStatus]",

      -- dbo table-valued functions (2 total - can be used in FROM)
      "[dbo].[fn_GetEmployeesBySalaryRange]",
      "[dbo].[GetCustomerOrders]",

      -- dbo synonyms (4 total - FROM-selectable)
      "[dbo].[syn_ActiveEmployees]",
      "[dbo].[syn_Depts]",
      "[dbo].[syn_Employees]",
      "[dbo].[syn_HRBenefits]"
    }
  }
}