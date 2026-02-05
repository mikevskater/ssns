-- Test 4425: CTE - CTE used in UPDATE FROM

return {
  number = 4425,
  description = "CTE - CTE used in UPDATE FROM",
  database = "vim_dadbod_test",
  query = [[WITH DeptAvg AS (SELECT DepartmentID, AVG(Salary) AS AvgSal FROM Employees GROUP BY DepartmentID)
UPDATE e SET e.Salary = d.AvgSal FROM Employees e JOIN █]],
  expected = {
    items = {
      includes = {
        "DeptAvg",
      },
    },
    type = "table",
  },
}
