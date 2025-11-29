-- Test 4741: Complex - deeply nested parentheses

return {
  number = 4741,
  description = "Complex - deeply nested parentheses",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE (((( █= 1))))",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "IsActive",
      },
    },
    type = "column",
  },
}
