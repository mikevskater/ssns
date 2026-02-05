-- Test 4467: Temp table - columns in ORDER BY
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4467,
  description = "Temp table - columns in ORDER BY",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100), Salary DECIMAL(10,2))
SELECT * FROM #TempEmployees ORDER BY █]],
  expected = {
    items = {
      includes = {
        "ID",
        "Name",
        "Salary",
      },
    },
    type = "column",
  },
}
