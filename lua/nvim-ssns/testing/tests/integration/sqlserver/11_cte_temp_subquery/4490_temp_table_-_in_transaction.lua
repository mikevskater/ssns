-- Test 4490: Temp table - in transaction
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4490,
  description = "Temp table - in transaction",
  database = "vim_dadbod_test",
  skip = false,
  query = [[BEGIN TRANSACTION
CREATE TABLE #TranTemp (ID INT, Name VARCHAR(100))
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "#TranTemp",
      },
    },
    type = "table",
  },
}
