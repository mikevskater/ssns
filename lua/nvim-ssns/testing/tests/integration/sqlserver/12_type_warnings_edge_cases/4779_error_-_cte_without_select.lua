-- Test 4779: Error - CTE without SELECT
-- SKIPPED: Error type completion not yet supported

return {
  number = 4779,
  description = "Error - CTE without SELECT",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Error type completion not yet supported",
  query = "WITH CTE AS (SELECT * FROM Employees)█",
  expected = {
    items = { includes = {} },
    type = "error",
  },
}
