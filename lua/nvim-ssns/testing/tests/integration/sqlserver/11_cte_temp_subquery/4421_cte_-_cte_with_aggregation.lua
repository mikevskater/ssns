-- Test 4421: CTE - CTE with aggregation

return {
  number = 4421,
  description = "CTE - CTE with aggregation",
  database = "vim_dadbod_test",
  query = [[WITH DeptStats AS (SELECT DepartmentID, COUNT(*) AS EmpCount, AVG(Salary) AS AvgSalary FROM Employees GROUP BY DepartmentID)
SELECT █ FROM DeptStats]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "EmpCount",
        "AvgSalary",
      },
    },
    type = "column",
  },
}
