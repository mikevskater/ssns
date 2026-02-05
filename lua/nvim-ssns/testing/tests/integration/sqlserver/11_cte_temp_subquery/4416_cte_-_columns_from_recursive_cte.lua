-- Test 4416: CTE - columns from recursive CTE

return {
  number = 4416,
  description = "CTE - columns from recursive CTE",
  database = "vim_dadbod_test",
  query = [[WITH EmpHierarchy AS (
  SELECT EmployeeID, DepartmentID, 1 AS Level FROM Employees WHERE DepartmentID IS NULL
  UNION ALL
  SELECT e.EmployeeID, e.DepartmentID, eh.Level + 1 FROM Employees e JOIN EmpHierarchy eh ON e.DepartmentID = eh.EmployeeID
)
SELECT █ FROM EmpHierarchy]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "DepartmentID",
        "Level",
      },
    },
    type = "column",
  },
}
