-- Test 4355: ON clause - compatible numeric types (int vs bigint)

return {
  number = 4355,
  description = "ON clause - compatible numeric types (int vs bigint)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Orders o ON e.EmployeeID = o.█Id",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
