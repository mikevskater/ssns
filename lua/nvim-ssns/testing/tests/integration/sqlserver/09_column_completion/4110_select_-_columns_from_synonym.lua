-- Test 4110: SELECT - columns from synonym

return {
  number = 4110,
  description = "SELECT - columns from synonym",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM syn_Employees",
  expected = {
    items = {
      includes_any = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
