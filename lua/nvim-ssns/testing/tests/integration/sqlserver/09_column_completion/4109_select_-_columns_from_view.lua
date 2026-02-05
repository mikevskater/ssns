-- Test 4109: SELECT - columns from view

return {
  number = 4109,
  description = "SELECT - columns from view",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM vw_ActiveEmployees",
  expected = {
    items = {
      includes_any = {
        "EmployeeID",
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
