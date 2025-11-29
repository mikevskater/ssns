-- Test 4255: CTE - ORDER BY completion

return {
  number = 4255,
  description = "CTE - ORDER BY completion",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT EmployeeID, FirstName FROM Employees)
SELECT * FROM EmpCTE ORDER BY █]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
