-- Test 4401: CTE - reference CTE name in FROM clause

return {
  number = 4401,
  description = "CTE - reference CTE name in FROM clause",
  database = "vim_dadbod_test",
  query = [[WITH EmployeeCTE AS (SELECT * FROM Employees)
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "EmployeeCTE",
        "Employees",
        "Departments",
      },
    },
    type = "table",
  },
}
