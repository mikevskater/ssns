-- Test 4252: CTE - recursive CTE columns

return {
  number = 4252,
  description = "CTE - recursive CTE columns",
  database = "vim_dadbod_test",
  query = [[WITH RECURSIVE EmpHierarchy AS (
  SELECT EmployeeID, ManagerID, FirstName, 1 as Level FROM Employees WHERE ManagerID IS NULL
  UNION ALL
  SELECT e.EmployeeID, e.ManagerID, e.FirstName, h.Level + 1 FROM Employees e JOIN EmpHierarchy h ON e.ManagerID = h.EmployeeID
)
SELECT █ FROM EmpHierarchy]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "ManagerID",
        "FirstName",
        "Level",
      },
    },
    type = "column",
  },
}
