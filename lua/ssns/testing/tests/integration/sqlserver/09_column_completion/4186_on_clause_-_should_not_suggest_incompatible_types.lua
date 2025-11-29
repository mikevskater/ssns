-- Test 4186: ON clause - should not suggest incompatible types

return {
  number = 4186,
  description = "ON clause - should not suggest incompatible types",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.FirstName = d.█",
  expected = {
    items = {
      excludes = {
        "DepartmentID",
      },
      includes_any = {
        "DepartmentName",
      },
    },
    type = "column",
  },
}
