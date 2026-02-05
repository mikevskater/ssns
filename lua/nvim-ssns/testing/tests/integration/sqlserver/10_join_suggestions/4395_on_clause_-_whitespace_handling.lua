-- Test 4395: ON clause - whitespace handling
-- SKIPPED: Whitespace handling in qualified column completion not yet supported

return {
  number = 4395,
  description = "ON clause - whitespace handling",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Whitespace handling around dot in qualified column reference not yet supported",
  query = "SELECT * FROM Employees e JOIN Departments d ON   e   .  █ ",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
