-- Test 4268: CTE - window function in CTE

return {
  number = 4268,
  description = "CTE - window function in CTE",
  database = "vim_dadbod_test",
  query = [[WITH Ranked AS (SELECT EmployeeID, ROW_NUMBER() OVER (ORDER BY Salary DESC) AS RowNum FROM Employees)
SELECT █ FROM Ranked]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "RowNum",
      },
    },
    type = "column",
  },
}
