-- Test 4164: ON clause - right side alias-qualified

return {
  number = 4164,
  description = "ON clause - right side alias-qualified",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.█",
  expected = {
    items = {
      excludes = {
        "FirstName",
      },
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
