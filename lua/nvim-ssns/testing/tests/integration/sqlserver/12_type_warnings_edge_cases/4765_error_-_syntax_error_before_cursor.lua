-- Test 4765: Error - syntax error before cursor
-- SKIPPED: Error type completion not yet supported

return {
  number = 4765,
  description = "Error - syntax error before cursor",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Error type completion not yet supported",
  query = "SELECT * FORM Employees WHERE █",
  expected = {
    items = { includes = {} },
    type = "error",
  },
}
