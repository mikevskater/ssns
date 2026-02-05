-- Test 4359: ON clause - compatible int types

return {
  number = 4359,
  description = "ON clause - compatible int types",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Customers c ON e.EmployeeID = c.I█d",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
