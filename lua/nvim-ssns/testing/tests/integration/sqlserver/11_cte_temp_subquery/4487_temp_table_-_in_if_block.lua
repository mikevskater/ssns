-- Test 4487: Temp table - in IF block
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4487,
  description = "Temp table - in IF block",
  database = "vim_dadbod_test",
  skip = false,
  query = [[IF 1=1
BEGIN
  CREATE TABLE #ConditionalTemp (ID INT)
  SELECT * FROM█
END]],
  expected = {
    items = {
      includes = {
        "#ConditionalTemp",
      },
    },
    type = "table",
  },
}
