-- Test 4371: ON clause - three table join, third table ON

return {
  number = 4371,
  description = "ON clause - three table join, third table ON",
  database = "vim_dadbod_test",
  skip = false,
  query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID
JOIN Projects p ON█ ]],
  expected = {
    items = {
      includes_any = {
        "p.ProjectID",
        "d.DepartmentID",
        "e.EmployeeID",
      },
    },
    type = "column",
  },
}
