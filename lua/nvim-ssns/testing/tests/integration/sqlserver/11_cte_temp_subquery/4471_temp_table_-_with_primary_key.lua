-- Test 4471: Temp table - with PRIMARY KEY
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4471,
  description = "Temp table - with PRIMARY KEY",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (ID INT PRIMARY KEY, Name VARCHAR(100) NOT NULL)
SELECT █ FROM #TempEmployees]],
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
