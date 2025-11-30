-- Test 4798: Context - cursor inside string literal
-- SKIPPED: None type completion not yet supported

return {
  number = 4798,
  description = "Context - cursor inside string literal",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "None type completion not yet supported",
  query = "SELECT * FROM Employees WHERE FirstName = 'Jo█'",
  expected = {
    items = { includes = {} },
    type = "none",
  },
}
