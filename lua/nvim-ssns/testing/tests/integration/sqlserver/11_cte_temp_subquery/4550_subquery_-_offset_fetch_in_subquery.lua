-- Test 4550: Subquery - OFFSET FETCH in subquery
-- SKIPPED: Derived table column completion not yet supported

return {
  number = 4550,
  description = "Subquery - OFFSET FETCH in subquery",
  database = "vim_dadbod_test",
  skip = false,
  query = "SELECT sub.█ FROM (SELECT EmployeeID, FirstName FROM Employees ORDER BY EmployeeID OFFSET 10 ROWS FETCH NEXT 5 ROWS ONLY) sub",
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
