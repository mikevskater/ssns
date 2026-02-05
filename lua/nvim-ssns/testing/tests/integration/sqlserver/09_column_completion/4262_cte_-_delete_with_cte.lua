-- Test 4262: CTE - DELETE with CTE

return {
  number = 4262,
  description = "CTE - DELETE with CTE",
  database = "vim_dadbod_test",
  query = [[WITH ToDelete AS (SELECT EmployeeID FROM Employees WHERE DepartmentID = 1)
DELETE FROM ToDelete WHERE █]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
