-- Test 4742: Complex - UNION with different column counts (error)
-- SKIPPED: Error type completion not yet supported

return {
  number = 4742,
  description = "Complex - UNION with different column counts (error)",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Error type completion not yet supported",
  query = "SELECT EmployeeID, FirstName FROM Employees UNION SELECT DepartmentID FROM Department█s",
  expected = {
    items = { includes = {} },
    type = "error",
  },
}
