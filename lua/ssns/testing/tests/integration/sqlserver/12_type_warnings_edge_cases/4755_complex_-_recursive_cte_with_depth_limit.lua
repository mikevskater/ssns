-- Test 4755: Complex - recursive CTE with depth limit

return {
  number = 4755,
  description = "Complex - recursive CTE with depth limit",
  database = "vim_dadbod_test",
  query = [[WITH RecCTE AS (
  SELECT EmployeeID, DepartmentID, 0 AS Depth FROM Employees WHERE DepartmentID IS NULL
  UNION ALL
  SELECT e.EmployeeID, e.DepartmentID, r.Depth + 1 FROM Employees e JOIN RecCTE r ON e.DepartmentID = r.EmployeeID WHERE r.Depth < 10
)
SELECT █ FROM RecCTE]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentID",
        "Depth",
      },
    },
    type = "column",
  },
}
