-- Test 4448: CTE - CTE referenced in MERGE statement

return {
  number = 4448,
  description = "CTE - CTE referenced in MERGE statement",
  database = "vim_dadbod_test",
  query = [[WITH SourceCTE AS (SELECT * FROM Employees WHERE DepartmentID = 1)
MERGE INTO Employees AS target
USING █ AS source
ON target.EmployeeID = source.EmployeeID]],
  expected = {
    items = {
      includes = {
        "SourceCTE",
      },
    },
    type = "table",
  },
}
