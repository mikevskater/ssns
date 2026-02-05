-- Test 4519: Subquery - APPLY column completion
-- SKIPPED: Derived table column completion not yet supported

return {
  number = 4519,
  description = "Subquery - APPLY column completion",
  database = "vim_dadbod_test",
  skip = false,
  query = "SELECT d.DepartmentName, x.█ FROM Departments d CROSS APPLY (SELECT TOP 5 EmployeeID, FirstName FROM Employees e WHERE e.DepartmentID = d.DepartmentID) x",
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
