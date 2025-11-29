-- Test 4258: CTE - aggregate in CTE

return {
  number = 4258,
  description = "CTE - aggregate in CTE",
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
