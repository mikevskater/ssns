-- Test 4491: Temp table - with schema prefix
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4491,
  description = "Temp table - with schema prefix",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (ID INT, Name VARCHAR(100))
SELECT * FROM dbo.█]],
  expected = {
    items = {
      excludes = {
        "#TempEmployees",
      },
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
