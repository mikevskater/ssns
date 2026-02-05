-- Test 4365: ON clause - suggest matching DepartmentID

return {
  number = 4365,
  description = "ON clause - suggest matching DepartmentID",
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
