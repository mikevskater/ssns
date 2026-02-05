-- Test 4475: Temp table - with CHECK constraint
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4475,
  description = "Temp table - with CHECK constraint",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (ID INT, Age INT CHECK (Age >= 18), Name VARCHAR(100))
SELECT █ FROM #TempEmployees]],
  expected = {
    items = {
      includes = {
        "ID",
        "Age",
        "Name",
      },
    },
    type = "column",
  },
}
