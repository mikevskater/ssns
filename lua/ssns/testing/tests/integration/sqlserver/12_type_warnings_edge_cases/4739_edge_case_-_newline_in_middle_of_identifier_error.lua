-- Test 4739: Edge case - newline in middle of identifier (error)
-- SKIPPED: Error type completion not yet supported

return {
  number = 4739,
  description = "Edge case - newline in middle of identifier (error)",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Error type completion not yet supported",
  query = [[SELECT First█
Name FROM Employees]],
  expected = {
    items = { includes = {} },
    type = "error",
  },
}
