-- Test 4260: CTE - CTE name completion in FROM

return {
  number = 4260,
  description = "CTE - CTE name completion in FROM",
  database = "vim_dadbod_test",
  query = [[WITH EmpCTE AS (SELECT EmployeeID FROM Employees)
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "EmpCTE",
        "Employees",
      },
    },
    type = "table",
  },
}
