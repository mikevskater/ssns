-- Test 4525: Subquery - three-level nesting columns
-- SKIPPED: Nested SELECT * column expansion through multiple levels not yet supported

return {
  number = 4525,
  description = "Subquery - three-level nesting columns",
  database = "vim_dadbod_test",
  skip = false,
  query = [[SELECT * FROM (
  SELECT * FROM (
    SELECT EmployeeID, FirstName FROM Employees
  ) inner1
) outer1 WHERE █]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
