-- Test 4731: Edge case - very long identifier (128 chars)

return {
  number = 4731,
  description = "Edge case - very long identifier (128 chars)",
  database = "vim_dadbod_test",
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
