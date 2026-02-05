-- Test 4261: CTE - UPDATE with CTE

return {
  number = 4261,
  description = "CTE - UPDATE with CTE",
  database = "vim_dadbod_test",
  query = [[WITH ToUpdate AS (SELECT EmployeeID, Salary FROM Employees WHERE DepartmentID = 1)
UPDATE ToUpdate SET █]],
  expected = {
    items = {
      includes = {
        "Salary",
      },
    },
    type = "column",
  },
}
