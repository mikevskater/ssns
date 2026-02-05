-- Test 4628: MERGE - USING subquery table

return {
  number = 4628,
  description = "MERGE - USING subquery table",
  database = "vim_dadbod_test",
  query = [[MERGE INTO Employees AS target
USING (SELECT * FROM █) AS source]],
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
