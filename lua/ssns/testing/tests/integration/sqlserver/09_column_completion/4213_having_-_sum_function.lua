-- Test 4213: HAVING - SUM function

return {
  number = 4213,
  description = "HAVING - SUM function",
  database = "vim_dadbod_test",
  query = "SELECT DepartmentID, SUM(Salary) FROM Employees GROUP BY DepartmentID HAVING SUM(█) > 100000",
  expected = {
    items = {
      includes = {
        "Salary",
      },
    },
    type = "column",
  },
}
