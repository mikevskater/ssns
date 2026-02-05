-- Test 4434: CTE - CTE with * expansion tracking

return {
  number = 4434,
  description = "CTE - CTE with * expansion tracking",
  database = "vim_dadbod_test",
  skip = false,
  query = [[WITH AllEmps AS (SELECT * FROM Employees)
SELECT * FROM AllEmps WHERE █]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "LastName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
