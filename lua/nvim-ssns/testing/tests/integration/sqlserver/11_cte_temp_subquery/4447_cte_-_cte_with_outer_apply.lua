-- Test 4447: CTE - CTE with OUTER APPLY

return {
  number = 4447,
  description = "CTE - CTE with OUTER APPLY",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT * FROM Employees)
SELECT * FROM EmpCTE e OUTER APPLY (SELECT TOP 1 * FROM Orders o WHERE o.EmployeeId = e.█) x]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
