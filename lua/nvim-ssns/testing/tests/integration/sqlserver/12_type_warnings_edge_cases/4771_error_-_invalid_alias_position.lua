-- Test 4771: Error - invalid alias position
-- SKIPPED: Error type completion not yet supported

return {
  number = 4771,
  description = "Error - invalid alias position",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Error type completion not yet supported",
  query = "SELECT AS █alias FROM Employees",
  expected = {
    items = { includes = {} },
    type = "error",
  },
}
