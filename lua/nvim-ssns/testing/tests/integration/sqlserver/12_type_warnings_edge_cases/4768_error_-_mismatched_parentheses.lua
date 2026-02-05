-- Test 4768: Error - mismatched parentheses

return {
  number = 4768,
  description = "Error - mismatched parentheses",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE (DepartmentID = 1█",
  expected = {
    items = {
      includes_any = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
