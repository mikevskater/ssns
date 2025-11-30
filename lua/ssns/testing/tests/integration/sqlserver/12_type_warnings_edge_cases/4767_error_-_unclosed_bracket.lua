-- Test 4767: Error - unclosed bracket
-- SKIPPED: Error type completion not yet supported

return {
  number = 4767,
  description = "Error - unclosed bracket",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Error type completion not yet supported",
  query = "SELECT * FROM [Employees WHERE █",
  expected = {
    items = { includes = {} },
    type = "error",
  },
}
