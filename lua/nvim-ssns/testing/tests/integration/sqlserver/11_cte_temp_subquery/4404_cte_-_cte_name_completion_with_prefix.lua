-- Test 4404: CTE - CTE name completion with prefix

return {
  number = 4404,
  description = "CTE - CTE name completion with prefix",
  database = "vim_dadbod_test",
  query = [[WITH EmployeeCTE AS (SELECT * FROM Employees)
SELECT * FROM Emp█]],
  expected = {
    items = {
      includes = {
        "EmployeeCTE",
        "Employees",
      },
    },
    type = "table",
  },
}
