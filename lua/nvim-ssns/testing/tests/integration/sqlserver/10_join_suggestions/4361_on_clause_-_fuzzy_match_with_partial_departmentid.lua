-- Test 4361: ON clause - fuzzy match with partial DepartmentID

return {
  number = 4361,
  description = "ON clause - fuzzy match with partial DepartmentID",
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
