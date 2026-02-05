-- Test 4428: CTE - CTE with CASE expression

return {
  number = 4428,
  description = "CTE - CTE with CASE expression",
  database = "vim_dadbod_test",
  query = [[WITH EmpCategory AS (SELECT EmployeeID, CASE WHEN Salary > 100000 THEN 'High' ELSE 'Normal' END AS SalaryCategory FROM Employees)
SELECT █ FROM EmpCategory]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "SalaryCategory",
      },
    },
    type = "column",
  },
}
