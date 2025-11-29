-- Test 4173: ON clause - second JOIN linking to first table

return {
  number = 4173,
  description = "ON clause - second JOIN linking to first table",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID JOIN Projects p ON p.ProjectID = e.█",
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
