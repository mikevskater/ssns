-- Test 4613: DELETE - WITH CTE

return {
  number = 4613,
  description = "DELETE - WITH CTE",
  database = "vim_dadbod_test",
  query = [[WITH ToDelete AS (SELECT * FROM Employees WHERE IsActive = 0)
DELETE FROM █]],
  expected = {
    items = {
      includes = {
        "ToDelete",
        "Employees",
      },
    },
    type = "table",
  },
}
