-- Test 4529: Subquery - subquery with CASE expression columns
-- SKIPPED: Derived table column completion not yet supported

return {
  number = 4529,
  description = "Subquery - subquery with CASE expression columns",
  database = "vim_dadbod_test",
  skip = false,
  query = [[SELECT sub.█ FROM (
  SELECT EmployeeID,
    CASE WHEN Salary > 100000 THEN 'High' ELSE 'Normal' END AS SalaryLevel
  FROM Employees
) sub]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "SalaryLevel",
      },
    },
    type = "column",
  },
}
