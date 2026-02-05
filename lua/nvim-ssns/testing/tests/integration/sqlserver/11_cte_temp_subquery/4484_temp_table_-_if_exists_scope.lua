-- Test 4484: Temp table - IF EXISTS scope
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4484,
  description = "Temp table - IF EXISTS scope",
  database = "vim_dadbod_test",
  skip = false,
  query = [[IF OBJECT_ID('tempdb..#TempEmployees') IS NOT NULL DROP TABLE #TempEmployees
CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "#TempEmployees",
      },
    },
    type = "table",
  },
}
