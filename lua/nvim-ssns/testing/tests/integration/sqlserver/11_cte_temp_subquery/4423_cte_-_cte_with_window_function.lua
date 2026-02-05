-- Test 4423: CTE - CTE with window function

return {
  number = 4423,
  description = "CTE - CTE with window function",
  database = "vim_dadbod_test",
  query = [[WITH RankedEmps AS (SELECT EmployeeID, FirstName, Salary, ROW_NUMBER() OVER (ORDER BY Salary DESC) AS Rank FROM Employees)
SELECT █ FROM RankedEmps]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "Salary",
        "Rank",
      },
    },
    type = "column",
  },
}
