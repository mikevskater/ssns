-- Test 4426: CTE - CTE used in DELETE

return {
  number = 4426,
  description = "CTE - CTE used in DELETE",
  database = "vim_dadbod_test",
  query = [[WITH ToDelete AS (SELECT EmployeeID FROM Employees WHERE IsActive = 0)
DELETE FROM Employees WHERE EmployeeID IN (SELECT █ FROM ToDelete)]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
