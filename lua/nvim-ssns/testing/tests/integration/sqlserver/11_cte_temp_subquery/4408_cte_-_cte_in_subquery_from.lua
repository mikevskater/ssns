-- Test 4408: CTE - CTE in subquery FROM

return {
  number = 4408,
  description = "CTE - CTE in subquery FROM",
  database = "vim_dadbod_test",
  query = [[WITH DeptCTE AS (SELECT * FROM Departments)
SELECT * FROM Employees WHERE DepartmentID IN (SELECT DepartmentID FROM █)]],
  expected = {
    items = {
      includes = {
        "DeptCTE",
        "Departments",
      },
    },
    type = "table",
  },
}
