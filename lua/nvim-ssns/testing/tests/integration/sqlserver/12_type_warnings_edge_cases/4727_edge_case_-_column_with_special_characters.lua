-- Test 4727: Edge case - column with special characters
-- SKIPPED: Test table does not exist in database

return {
  number = 4727,
  description = "Edge case - column with special characters",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Test table does not exist in database",
  query = "SELECT [Column#1], [Column@2]█ FROM SpecialChars",
  expected = {
    items = {
      includes_any = {
        "Column#1",
        "Column@2",
      },
    },
    type = "column",
  },
}
