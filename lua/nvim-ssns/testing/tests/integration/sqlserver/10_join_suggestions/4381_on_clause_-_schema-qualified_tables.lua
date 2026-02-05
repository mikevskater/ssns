-- Test 4381: ON clause - schema-qualified tables

return {
  number = 4381,
  description = "ON clause - schema-qualified tables",
  database = "vim_dadbod_test",
  query = "SELECT * FROM dbo.Employees e JOIN dbo.Departments d ON e.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "EmployeeID",
      },
    },
    type = "column",
  },
}
