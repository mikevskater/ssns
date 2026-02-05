-- Test 4470: Temp table - alias-qualified columns
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4470,
  description = "Temp table - alias-qualified columns",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
SELECT te.ID, te.█ FROM #TempEmployees te]],
  expected = {
    items = {
      includes = {
        "Name",
      },
    },
    type = "column",
  },
}
