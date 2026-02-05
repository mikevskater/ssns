-- Test 4431: CTE - CTE name shadows table name

return {
  number = 4431,
  description = "CTE - CTE name shadows table name",
  database = "vim_dadbod_test",
  query = [[WITH Employees AS (SELECT EmployeeID, FirstName FROM Employees WHERE DepartmentID = 1)
SELECT █ FROM Employees]],
  expected = {
    items = {
      excludes = {
        "LastName",
        "DepartmentID",
      },
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
