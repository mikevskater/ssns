-- Test 4407: CTE - recursive CTE reference

return {
  number = 4407,
  description = "CTE - recursive CTE reference",
  database = "vim_dadbod_test",
  query = [[WITH EmpHierarchy AS (
  SELECT EmployeeID, DepartmentID, 1 AS Level FROM Employees WHERE DepartmentID IS NULL
  UNION ALL
  SELECT e.EmployeeID, e.DepartmentID, eh.Level + 1 FROM Employees e JOIN EmpHierarchy eh ON e.DepartmentID = eh.EmployeeID
)
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "EmpHierarchy",
        "Employees",
      },
    },
    type = "table",
  },
}
