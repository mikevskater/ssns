-- Test 4410: CTE - case insensitive CTE name

return {
  number = 4410,
  description = "CTE - case insensitive CTE name",
  database = "vim_dadbod_test",
  query = [[WITH employeecte AS (SELECT * FROM Employees)
SELECT * FROM EMPLOYEE█]],
  expected = {
    items = {
      includes_any = {
        "employeecte",
        "EmployeeCTE",
        "Employees",
      },
    },
    type = "table",
  },
}
