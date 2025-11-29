-- Test 4172: ON clause - second JOIN alias-qualified

return {
  number = 4172,
  description = "ON clause - second JOIN alias-qualified",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN Projects p ON p.█",
  expected = {
    items = {
      excludes = {
        "FirstName",
      },
      includes = {
        "ProjectID",
        "ProjectName",
      },
    },
    type = "column",
  },
}
