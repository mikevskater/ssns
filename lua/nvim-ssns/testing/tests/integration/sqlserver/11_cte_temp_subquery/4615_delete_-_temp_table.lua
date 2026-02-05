-- Test 4615: DELETE - temp table
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4615,
  description = "DELETE - temp table",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmp (ID INT, Name VARCHAR(100))
DELETE FROM #TempEmp WHERE █]],
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
