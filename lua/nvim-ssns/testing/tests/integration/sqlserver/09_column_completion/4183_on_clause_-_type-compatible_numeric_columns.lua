-- Test 4183: ON clause - type-compatible numeric columns

return {
  number = 4183,
  description = "ON clause - type-compatible numeric columns",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
