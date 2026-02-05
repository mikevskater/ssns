-- Test 4207: GROUP BY - with WHERE

return {
  number = 4207,
  description = "GROUP BY - with WHERE",
  database = "vim_dadbod_test",
  query = "SELECT DepartmentID, COUNT(*) FROM Employees WHERE Salary > 50000 GROUP BY █",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
