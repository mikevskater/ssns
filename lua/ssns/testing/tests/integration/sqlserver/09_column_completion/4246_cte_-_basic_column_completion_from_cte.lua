-- Test 4246: CTE - basic column completion from CTE

return {
  number = 4246,
  description = "CTE - basic column completion from CTE",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT EmployeeID, FirstName FROM Employees)
SELECT █ FROM EmpCTE]],
  expected = {
    items = {
      excludes = {
        "LastName",
      },
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
