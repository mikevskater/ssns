-- Test 4777: Error - UPDATE without SET
-- SKIPPED: Error type completion not yet supported

return {
  number = 4777,
  description = "Error - UPDATE without SET",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Error type completion not yet supported",
  query = "UPDATE Employees WHERE EmployeeID = 1█",
  expected = {
    items = { includes = {} },
    type = "error",
  },
}
