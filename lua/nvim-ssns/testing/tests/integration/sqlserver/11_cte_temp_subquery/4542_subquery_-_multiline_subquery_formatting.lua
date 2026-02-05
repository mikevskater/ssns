-- Test 4542: Subquery - multiline subquery formatting
-- SKIPPED: Derived table column completion not yet supported

return {
  number = 4542,
  description = "Subquery - multiline subquery formatting",
  database = "vim_dadbod_test",
  skip = false,
  query = [[SELECT sub.█
FROM (
  SELECT
    EmployeeID,
    FirstName,
    LastName
  FROM Employees
) sub]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
