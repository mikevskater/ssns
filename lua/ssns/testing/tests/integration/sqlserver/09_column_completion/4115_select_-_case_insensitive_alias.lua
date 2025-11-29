-- Test 4115: SELECT - case insensitive alias

return {
  number = 4115,
  description = "SELECT - case insensitive alias",
  database = "vim_dadbod_test",
  query = "SELECT E.█ FROM Employees e",
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
