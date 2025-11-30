-- Test 4778: Error - DELETE with invalid syntax
-- SKIPPED: Error type completion not yet supported

return {
  number = 4778,
  description = "Error - DELETE with invalid syntax",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Error type completion not yet supported",
  query = "DELETE Employees SET█",
  expected = {
    items = { includes = {} },
    type = "error",
  },
}
