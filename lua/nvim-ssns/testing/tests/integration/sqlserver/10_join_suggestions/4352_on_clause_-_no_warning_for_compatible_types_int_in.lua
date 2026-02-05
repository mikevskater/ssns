-- Test 4352: ON clause - no warning for compatible types (int = int)

return {
  number = 4352,
  description = "ON clause - no warning for compatible types (int = int)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
