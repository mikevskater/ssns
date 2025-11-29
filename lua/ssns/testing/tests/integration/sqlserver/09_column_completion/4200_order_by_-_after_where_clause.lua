-- Test 4200: ORDER BY - after WHERE clause

return {
  number = 4200,
  description = "ORDER BY - after WHERE clause",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE DepartmentID = 1 ORDER BY █",
  expected = {
    items = {
      includes = {
        "FirstName",
        "Salary",
      },
    },
    type = "column",
  },
}
