-- Test 4113: SELECT - unqualified columns with alias in FROM

return {
  number = 4113,
  description = "SELECT - unqualified columns with alias in FROM",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM Employees e",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
