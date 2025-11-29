-- Test 4108: SELECT - table-qualified column completion

return {
  number = 4108,
  description = "SELECT - table-qualified column completion",
  database = "vim_dadbod_test",
  query = "SELECT Employees.█ FROM Employees",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
