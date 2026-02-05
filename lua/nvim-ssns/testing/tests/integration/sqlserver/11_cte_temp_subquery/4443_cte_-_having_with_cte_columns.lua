-- Test 4443: CTE - HAVING with CTE columns

return {
  number = 4443,
  description = "CTE - HAVING with CTE columns",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT DepartmentID, Salary FROM Employees)
SELECT DepartmentID, AVG(Salary) FROM EmpCTE GROUP BY DepartmentID HAVING AVG(█) > 50000]],
  expected = {
    items = {
      includes = {
        "Salary",
      },
    },
    type = "column",
  },
}
