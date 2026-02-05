-- Test 4354: ON clause - compatible varchar types

return {
  number = 4354,
  description = "ON clause - compatible varchar types",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.FirstName = d.DepartmentName█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
