-- Test 4496: Temp table - TRUNCATE TABLE
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4496,
  description = "Temp table - TRUNCATE TABLE",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
TRUNCATE TABLE █]],
  expected = {
    items = {
      includes = {
        "#TempEmployees",
      },
    },
    type = "table",
  },
}
