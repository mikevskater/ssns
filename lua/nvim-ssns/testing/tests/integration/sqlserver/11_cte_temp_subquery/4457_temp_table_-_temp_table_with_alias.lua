-- Test 4457: Temp table - temp table with alias
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4457,
  description = "Temp table - temp table with alias",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
SELECT t.█ FROM #TempEmployees t]],
  expected = {
    items = {
      includes = {
        "ID",
        "Name",
      },
    },
    type = "column",
  },
}
