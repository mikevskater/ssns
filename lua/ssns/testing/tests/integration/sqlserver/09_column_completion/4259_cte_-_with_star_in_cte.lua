-- Test 4259: CTE - with star in CTE

return {
  number = 4259,
  description = "CTE - with star in CTE",
  database = "vim_dadbod_test",
  query = [[WITH AllEmps AS (SELECT * FROM Employees)
SELECT a.█ FROM AllEmps a]],
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
