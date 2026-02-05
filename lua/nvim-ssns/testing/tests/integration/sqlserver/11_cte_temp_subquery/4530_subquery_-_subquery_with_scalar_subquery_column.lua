-- Test 4530: Subquery - subquery with scalar subquery column
-- SKIPPED: Derived table column completion not yet supported

return {
  number = 4530,
  description = "Subquery - subquery with scalar subquery column",
  database = "vim_dadbod_test",
  skip = false,
  query = [[SELECT sub.█ FROM (
  SELECT EmployeeID,
    (SELECT DepartmentName FROM Departments d WHERE d.DepartmentID = e.DepartmentID) AS DeptName
  FROM Employees e
) sub]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DeptName",
      },
    },
    type = "column",
  },
}
