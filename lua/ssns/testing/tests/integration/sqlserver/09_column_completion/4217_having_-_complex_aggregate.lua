-- Test 4217: HAVING - complex aggregate

return {
  number = 4217,
  description = "HAVING - complex aggregate",
  database = "vim_dadbod_test",
  query = "SELECT DepartmentID FROM Employees GROUP BY DepartmentID HAVING AVG() >█ 50000",
  expected = {
    items = {
      includes = {
        "Salary",
      },
    },
    type = "column",
  },
}
