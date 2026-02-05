-- Test 4254: CTE - WHERE clause completion

return {
  number = 4254,
  description = "CTE - WHERE clause completion",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT EmployeeID, FirstName, Salary FROM Employees)
SELECT * FROM EmpCTE WHERE █]],
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
