-- Test 4549: Subquery - TOP in subquery
-- SKIPPED: Derived table column completion not yet supported

return {
  number = 4549,
  description = "Subquery - TOP in subquery",
  database = "vim_dadbod_test",
  skip = false,
  query = "SELECT sub.█ FROM (SELECT TOP 10 * FROM Employees ORDER BY Salary DESC) sub",
  expected = {
    items = {
      includes_any = {
        "EmployeeID",
        "Salary",
      },
    },
    type = "column",
  },
}
