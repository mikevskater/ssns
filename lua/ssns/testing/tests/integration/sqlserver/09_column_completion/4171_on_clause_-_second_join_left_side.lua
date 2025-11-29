-- Test 4171: ON clause - second JOIN left side

return {
  number = 4171,
  description = "ON clause - second JOIN left side",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN Projects p ON █",
  expected = {
    items = {
      includes = {
        "ProjectID",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
