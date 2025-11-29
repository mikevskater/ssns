-- Test 4745: Complex - multiple CTEs with UNION

return {
  number = 4745,
  description = "Complex - multiple CTEs with UNION",
  database = "vim_dadbod_test",
  query = [[WITH
  CTE1 AS (SELECT EmployeeID FROM Employees),
  CTE2 AS (SELECT EmployeeID FROM Employees WHERE DepartmentID = 1)
SELECT * FROM CTE1
UNION ALL
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "CTE2",
        "CTE1",
      },
    },
    type = "table",
  },
}
