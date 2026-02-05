-- Test 4442: CTE - GROUP BY with CTE columns

return {
  number = 4442,
  description = "CTE - GROUP BY with CTE columns",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT DepartmentID, Salary FROM Employees)
SELECT DepartmentID, SUM(Salary) FROM EmpCTE GROUP BY █]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
