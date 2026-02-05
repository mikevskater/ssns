-- Test 4523: Subquery - derived table with window function
-- SKIPPED: Derived table column completion not yet supported

return {
  number = 4523,
  description = "Subquery - derived table with window function",
  database = "vim_dadbod_test",
  skip = false,
  query = "SELECT sub.█ FROM (SELECT EmployeeID, Salary, ROW_NUMBER() OVER (ORDER BY Salary DESC) AS Rank FROM Employees) sub",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "Salary",
        "Rank",
      },
    },
    type = "column",
  },
}
