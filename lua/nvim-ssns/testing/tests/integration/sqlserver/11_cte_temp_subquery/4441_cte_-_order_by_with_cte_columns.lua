-- Test 4441: CTE - ORDER BY with CTE columns

return {
  number = 4441,
  description = "CTE - ORDER BY with CTE columns",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT EmployeeID, FirstName, Salary FROM Employees)
SELECT * FROM EmpCTE ORDER BY █]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "Salary",
      },
    },
    type = "column",
  },
}
