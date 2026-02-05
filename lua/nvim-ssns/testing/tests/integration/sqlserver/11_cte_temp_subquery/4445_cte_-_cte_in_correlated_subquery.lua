-- Test 4445: CTE - CTE in correlated subquery

return {
  number = 4445,
  description = "CTE - CTE in correlated subquery",
  database = "vim_dadbod_test",
  query = [[WITH DeptCTE AS (SELECT DepartmentID, Budget FROM Departments)
SELECT * FROM Employees e WHERE e.Salary > (SELECT Budget FROM DeptCTE d WHERE d.DepartmentID = e.█)]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
