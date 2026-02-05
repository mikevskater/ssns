-- Test 4247: CTE - alias-qualified column

return {
  number = 4247,
  description = "CTE - alias-qualified column",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT EmployeeID, FirstName FROM Employees)
SELECT c.█ FROM EmpCTE c]],
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
