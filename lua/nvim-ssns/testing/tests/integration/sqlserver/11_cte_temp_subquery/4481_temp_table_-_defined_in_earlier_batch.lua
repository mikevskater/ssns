-- Test 4481: Temp table - defined in earlier batch
-- Local temp tables are NOT visible after GO (batch terminator)

return {
  number = 4481,
  description = "Temp table - defined in earlier batch",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
GO
SELECT * FROM █]],
  expected = {
    items = {
      excludes = {
        "#TempEmployees",
      },
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
