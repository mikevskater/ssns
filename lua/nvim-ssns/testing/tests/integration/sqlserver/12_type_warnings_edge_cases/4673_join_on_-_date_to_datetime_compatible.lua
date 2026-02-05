-- Test 4673: JOIN ON - date to datetime (compatible)

return {
  number = 4673,
  description = "JOIN ON - date to datetime (compatible)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Customers c ON e.HireDate = c.CreatedDate█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
