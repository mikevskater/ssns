-- Test 4161: ON clause - basic left side completion

return {
  number = 4161,
  description = "ON clause - basic left side completion",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON █",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
