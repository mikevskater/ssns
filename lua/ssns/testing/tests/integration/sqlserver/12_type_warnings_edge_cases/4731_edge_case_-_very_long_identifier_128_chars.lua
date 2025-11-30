-- Test 4731: Edge case - very long identifier (128 chars)
-- SKIPPED: Test table does not exist in database

return {
  number = 4731,
  description = "Edge case - very long identifier (128 chars)",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Test table does not exist in database",
  query = "SELECT * FROM VeryLongTableNameThatIsExactlyOneHundredAndTwentyEightCharactersLongWhichIsTheMaximumAllowedB█yS",
  expected = {
    items = {
      includes_any = {
        "VeryLongTableName",
      },
    },
    type = "table",
  },
}
