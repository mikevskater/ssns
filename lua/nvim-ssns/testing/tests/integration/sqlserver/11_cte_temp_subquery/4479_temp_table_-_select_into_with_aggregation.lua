-- Test 4479: Temp table - SELECT INTO with aggregation
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4479,
  description = "Temp table - SELECT INTO with aggregation",
  database = "vim_dadbod_test",
  skip = false,
  query = [[SELECT DepartmentID, COUNT(*) AS EmpCount, AVG(Salary) AS AvgSalary
INTO #DeptStats
FROM Employees GROUP BY DepartmentID
SELECT █ FROM #DeptStats]],
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
