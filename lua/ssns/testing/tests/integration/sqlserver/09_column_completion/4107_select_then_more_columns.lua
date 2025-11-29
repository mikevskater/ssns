-- Test 4107: SELECT * then more columns

return {
  number = 4107,
  description = "SELECT * then more columns",
  database = "vim_dadbod_test",
  query = "SELECT *, █ FROM Employees",
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
