-- Test 4368: ON clause - fuzzy match with camelCase variation

return {
  number = 4368,
  description = "ON clause - fuzzy match with camelCase variation",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.departmentId = d.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
