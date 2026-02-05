-- Test 4522: Subquery - derived table with aggregation
-- SKIPPED: Derived table column completion not yet supported

return {
  number = 4522,
  description = "Subquery - derived table with aggregation",
  database = "vim_dadbod_test",
  skip = false,
  query = "SELECT sub.█ FROM (SELECT DepartmentID, COUNT(*) AS EmpCount, AVG(Salary) AS AvgSal FROM Employees GROUP BY DepartmentID) sub",
  expected = {
    items = {
      includes = {
        "DepartmentID",
        "EmpCount",
        "AvgSal",
      },
    },
    type = "column",
  },
}
