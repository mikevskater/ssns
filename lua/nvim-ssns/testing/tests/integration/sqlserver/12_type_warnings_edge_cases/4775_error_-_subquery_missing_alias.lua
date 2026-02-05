-- Test 4775: Error - subquery missing alias
-- SKIPPED: Error type completion not yet supported

return {
  number = 4775,
  description = "Error - subquery missing alias",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Error type completion not yet supported",
  query = "SELECT * FROM (SELECT * FROM Employees)█",
  expected = {
    items = { includes = {} },
    type = "error",
  },
}
