-- Test 4452: Temp table - local temp table with prefix filter
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4452,
  description = "Temp table - local temp table with prefix filter",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
SELECT * FROM #Temp█]],
  expected = {
    items = {
      includes = {
        "#TempEmployees",
      },
    },
    type = "table",
  },
}
