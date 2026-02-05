-- Test 4440: CTE - empty column list error handling

return {
  number = 4440,
  description = "CTE - empty column list error handling",
  database = "vim_dadbod_test",
  query = [[WITH InvalidCTE () AS (SELECT * FROM Employees)
SELECT * FROM █]],
  expected = {
    items = {
      includes_any = {
        "Employees",
        "Departments",
      },
    },
    type = "table",
  },
}
