-- Test 4432: CTE - CTE with same column names from different sources

return {
  number = 4432,
  description = "CTE - CTE with same column names from different sources",
  database = "vim_dadbod_test",
  query = [[WITH Combined AS (
  SELECT DepartmentID FROM Employees
  UNION
  SELECT DepartmentID FROM Departments
)
SELECT █ FROM Combined]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
