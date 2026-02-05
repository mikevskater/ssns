-- Test 4430: CTE - CTE in EXISTS subquery

return {
  number = 4430,
  description = "CTE - CTE in EXISTS subquery",
  database = "vim_dadbod_test",
  query = [[WITH ActiveDepts AS (SELECT DepartmentID FROM Departments WHERE Budget > 0)
SELECT * FROM Employees e WHERE EXISTS (SELECT 1 FROM █ WHERE DepartmentID = e.DepartmentID)]],
  expected = {
    items = {
      includes = {
        "ActiveDepts",
        "Departments",
      },
    },
    type = "table",
  },
}
