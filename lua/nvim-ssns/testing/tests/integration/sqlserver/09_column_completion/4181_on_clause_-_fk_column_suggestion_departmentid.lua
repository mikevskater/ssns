-- Test 4181: ON clause - FK column suggestion (DepartmentID)

return {
  number = 4181,
  description = "ON clause - FK column suggestion (DepartmentID)",
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
