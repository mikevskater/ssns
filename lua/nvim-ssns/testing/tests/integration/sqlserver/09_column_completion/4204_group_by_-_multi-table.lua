-- Test 4204: GROUP BY - multi-table

return {
  number = 4204,
  description = "GROUP BY - multi-table",
  database = "vim_dadbod_test",
  query = "SELECT d.DepartmentName, COUNT(*) FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID GROUP BY █",
  expected = {
    items = {
      includes = {
        "DepartmentName",
        "FirstName",
      },
    },
    type = "column",
  },
}
