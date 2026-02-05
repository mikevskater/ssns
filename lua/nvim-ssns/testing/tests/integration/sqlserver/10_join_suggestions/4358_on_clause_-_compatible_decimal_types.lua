-- Test 4358: ON clause - compatible decimal types

return {
  number = 4358,
  description = "ON clause - compatible decimal types",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Projects p ON e.Salary = p.Budg█et",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
