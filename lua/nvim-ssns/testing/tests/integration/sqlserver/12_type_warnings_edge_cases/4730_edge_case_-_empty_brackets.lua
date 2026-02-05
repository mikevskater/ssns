-- Test 4730: Edge case - empty brackets
-- SKIPPED: Error type completion not yet supported

return {
  number = 4730,
  description = "Edge case - empty brackets",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Error type completion not yet supported",
  query = "SELECT * FROM [].█",
  expected = {
    items = { includes = {} },
    type = "error",
  },
}
