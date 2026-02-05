-- Test 4438: CTE - CTE with TOP clause

return {
  number = 4438,
  description = "CTE - CTE with TOP clause",
  database = "vim_dadbod_test",
  skip = false,
  query = [[WITH TopEmps AS (SELECT TOP 10 * FROM Employees ORDER BY Salary DESC)
SELECT █ FROM TopEmps]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "Salary",
      },
    },
    type = "column",
  },
}
