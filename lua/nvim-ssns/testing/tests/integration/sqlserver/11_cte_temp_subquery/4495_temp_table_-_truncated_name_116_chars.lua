-- Test 4495: Temp table - truncated name (116+ chars)
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4495,
  description = "Temp table - truncated name (116+ chars)",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #ThisIsAVeryLongTableNameThatWillBeTruncatedBySQL (ID INT)
SELECT * FROM #This█]],
  expected = {
    items = {
      includes_any = {
        "#ThisIsAVeryLongTableNameThatWillBeTruncatedBySQL",
      },
    },
    type = "table",
  },
}
