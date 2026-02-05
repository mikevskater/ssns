-- Test 4170: ON clause - schema-qualified tables

return {
  number = 4170,
  description = "ON clause - schema-qualified tables",
  database = "vim_dadbod_test",
  query = "SELECT * FROM dbo.Employees e JOIN dbo.Departments d ON e.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
