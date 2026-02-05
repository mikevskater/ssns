-- Test 4480: Temp table - with index definition
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4480,
  description = "Temp table - with index definition",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100), INDEX IX_Name (Name))
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
