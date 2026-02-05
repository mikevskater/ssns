-- Test 4362: ON clause - suggest EmployeeID based on context

return {
  number = 4362,
  description = "ON clause - suggest EmployeeID based on context",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Orders o ON o.EmployeeId = e.█",
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
