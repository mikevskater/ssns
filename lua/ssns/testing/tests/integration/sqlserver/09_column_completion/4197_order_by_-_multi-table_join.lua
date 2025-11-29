-- Test 4197: ORDER BY - multi-table JOIN

return {
  number = 4197,
  description = "ORDER BY - multi-table JOIN",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID ORDER BY █",
  expected = {
    items = {
      includes = {
        "FirstName",
        "DepartmentName",
      },
    },
    type = "column",
  },
}
