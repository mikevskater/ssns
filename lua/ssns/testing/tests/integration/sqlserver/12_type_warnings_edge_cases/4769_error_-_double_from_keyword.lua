-- Test 4769: Error - double FROM keyword
-- SKIPPED: Error type completion not yet supported

return {
  number = 4769,
  description = "Error - double FROM keyword",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Error type completion not yet supported",
  query = "SELECT * FROM FROM █Employees",
  expected = {
    items = { includes = {} },
    type = "error",
  },
}
