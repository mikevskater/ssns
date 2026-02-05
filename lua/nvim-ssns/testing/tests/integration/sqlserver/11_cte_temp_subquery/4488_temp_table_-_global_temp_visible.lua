-- Test 4488: Temp table - global temp visible
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4488,
  description = "Temp table - global temp visible",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE ##GlobalTemp (ID INT, Name VARCHAR(100))
GO
SELECT * FROM ##█]],
  expected = {
    items = {
      includes = {
        "##GlobalTemp",
      },
    },
    type = "table",
  },
}
