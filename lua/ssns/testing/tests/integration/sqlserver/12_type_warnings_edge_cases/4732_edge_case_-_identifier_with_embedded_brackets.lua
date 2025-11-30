-- Test 4732: Edge case - identifier with embedded brackets
-- SKIPPED: Error type completion not yet supported

return {
  number = 4732,
  description = "Edge case - identifier with embedded brackets",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Error type completion not yet supported",
  query = "SELECT * FROM [Table[With]Brackets]█ ",
  expected = {
    items = { includes = {} },
    type = "error",
  },
}
