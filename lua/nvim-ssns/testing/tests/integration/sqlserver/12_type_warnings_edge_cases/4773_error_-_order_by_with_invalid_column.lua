-- Test 4773: Error - ORDER BY with invalid column

return {
  number = 4773,
  description = "Error - ORDER BY with invalid column",
  database = "vim_dadbod_test",
  query = "SELECT EmployeeID FROM Employees ORDER BY █",
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
