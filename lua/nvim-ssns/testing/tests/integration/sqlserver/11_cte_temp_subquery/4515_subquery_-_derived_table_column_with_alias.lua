-- Test 4515: Subquery - derived table column with alias
-- SKIPPED: Derived table column completion not yet supported

return {
  number = 4515,
  description = "Subquery - derived table column with alias",
  database = "vim_dadbod_test",
  skip = false,
  query = "SELECT sub.█ FROM (SELECT EmployeeID AS ID, FirstName AS Name FROM Employees) sub",
  expected = {
    items = {
      excludes = {
        "EmployeeID",
        "FirstName",
      },
      includes = {
        "ID",
        "Name",
      },
    },
    type = "column",
  },
}
