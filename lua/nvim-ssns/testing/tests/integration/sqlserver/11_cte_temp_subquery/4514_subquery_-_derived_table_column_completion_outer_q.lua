-- Test 4514: Subquery - derived table column completion outer query
-- SKIPPED: Derived table column completion not yet supported

return {
  number = 4514,
  description = "Subquery - derived table column completion outer query",
  database = "vim_dadbod_test",
  skip = false,
  query = "SELECT sub.█ FROM (SELECT EmployeeID, FirstName FROM Employees) sub",
  expected = {
    items = {
      excludes = {
        "LastName",
        "DepartmentID",
      },
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
