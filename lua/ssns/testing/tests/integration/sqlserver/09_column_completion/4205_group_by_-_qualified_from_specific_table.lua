-- Test 4205: GROUP BY - qualified from specific table

return {
  number = 4205,
  description = "GROUP BY - qualified from specific table",
  database = "vim_dadbod_test",
  query = "SELECT d.DepartmentName, COUNT(*) FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID GROUP BY d.█",
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
