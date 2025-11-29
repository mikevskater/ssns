-- Test 4215: HAVING - multi-table

return {
  number = 4215,
  description = "HAVING - multi-table",
  database = "vim_dadbod_test",
  query = "SELECT d.DepartmentName, COUNT(*) FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID GROUP BY d.DepartmentName HAVING █",
  expected = {
    items = {
      includes = {
        "DepartmentName",
      },
    },
    type = "column",
  },
}
