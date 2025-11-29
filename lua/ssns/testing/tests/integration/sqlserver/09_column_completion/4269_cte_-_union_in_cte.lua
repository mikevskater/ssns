-- Test 4269: CTE - UNION in CTE

return {
  number = 4269,
  description = "CTE - UNION in CTE",
  database = "vim_dadbod_test",
  query = [[WITH Combined AS (
  SELECT EmployeeID, FirstName FROM Employees WHERE DepartmentID = 1
  UNION ALL
  SELECT EmployeeID, FirstName FROM Employees WHERE DepartmentID = 2
)
SELECT █ FROM Combined]],
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
