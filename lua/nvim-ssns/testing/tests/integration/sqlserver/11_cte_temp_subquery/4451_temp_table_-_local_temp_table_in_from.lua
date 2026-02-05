-- Test 4451: Temp table - local temp table in FROM
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4451,
  description = "Temp table - local temp table in FROM",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "#TempEmployees",
        "Employees",
      },
    },
    type = "table",
  },
}
