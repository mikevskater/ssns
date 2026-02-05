-- Test 4267: CTE - CASE expression in CTE

return {
  number = 4267,
  description = "CTE - CASE expression in CTE",
  database = "vim_dadbod_test",
  query = [[WITH SalaryBands AS (SELECT EmployeeID, CASE WHEN Salary > 100000 THEN 'High' ELSE 'Low' END AS Band FROM Employees)
SELECT █ FROM SalaryBands]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "Band",
      },
    },
    type = "column",
  },
}
