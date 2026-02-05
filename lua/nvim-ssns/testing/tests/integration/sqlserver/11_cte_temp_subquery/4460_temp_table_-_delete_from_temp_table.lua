-- Test 4460: Temp table - DELETE FROM temp table
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4460,
  description = "Temp table - DELETE FROM temp table",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
DELETE FROM █]],
  expected = {
    items = {
      includes = {
        "#TempEmployees",
      },
    },
    type = "table",
  },
}
