-- Test 4766: Error - unclosed string literal
-- SKIPPED: Error type completion not yet supported

return {
  number = 4766,
  description = "Error - unclosed string literal",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Error type completion not yet supported",
  query = "SELECT * FROM Employees WHERE FirstName = 'John█",
  expected = {
    items = { includes = {} },
    type = "error",
  },
}
