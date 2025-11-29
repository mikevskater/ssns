-- Test 4162: ON clause - alias-qualified left side

return {
  number = 4162,
  description = "ON clause - alias-qualified left side",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.█",
  expected = {
    items = {
      excludes = {
        "DepartmentName",
      },
      includes = {
        "DepartmentID",
        "EmployeeID",
      },
    },
    type = "column",
  },
}
