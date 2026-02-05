-- Test 4111: SELECT - alias-qualified columns

return {
  number = 4111,
  description = "SELECT - alias-qualified columns",
  database = "vim_dadbod_test",
  query = "SELECT e.█ FROM Employees e",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "LastName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
