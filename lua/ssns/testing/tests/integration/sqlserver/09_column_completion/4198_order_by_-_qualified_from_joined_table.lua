-- Test 4198: ORDER BY - qualified from joined table

return {
  number = 4198,
  description = "ORDER BY - qualified from joined table",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID ORDER BY d.█",
  expected = {
    items = {
      excludes = {
        "FirstName",
      },
      includes = {
        "DepartmentName",
      },
    },
    type = "column",
  },
}
