-- Test 4776: Error - INSERT without VALUES or SELECT
-- SKIPPED: Error type completion not yet supported

return {
  number = 4776,
  description = "Error - INSERT without VALUES or SELECT",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Error type completion not yet supported",
  query = "INSERT INTO Employees (EmployeeID)█",
  expected = {
    items = { includes = {} },
    type = "error",
  },
}
