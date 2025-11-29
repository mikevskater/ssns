-- Test 4270: CTE - nested CTE reference chain

return {
  number = 4270,
  description = "CTE - nested CTE reference chain",
  database = "vim_dadbod_test",
  query = [[WITH
  Level1 AS (SELECT EmployeeID FROM Employees),
  Level2 AS (SELECT * FROM Level1),
  Level3 AS (SELECT * FROM Level2)
SELECT █ FROM Level3]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
