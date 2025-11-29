-- Test 4102: SELECT - columns with prefix filter

return {
  number = 4102,
  description = "SELECT - columns with prefix filter",
  database = "vim_dadbod_test",
  query = "SELECT First█ FROM Employees",
  expected = {
    items = {
      excludes = {
        "LastName",
        "EmployeeID",
      },
      includes = {
        "FirstName",
      },
    },
    type = "column",
  },
}
