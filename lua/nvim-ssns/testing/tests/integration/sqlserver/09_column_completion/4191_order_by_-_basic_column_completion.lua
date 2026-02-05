-- Test 4191: ORDER BY - basic column completion

return {
  number = 4191,
  description = "ORDER BY - basic column completion",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees ORDER BY █",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "LastName",
        "Salary",
      },
    },
    type = "column",
  },
}
