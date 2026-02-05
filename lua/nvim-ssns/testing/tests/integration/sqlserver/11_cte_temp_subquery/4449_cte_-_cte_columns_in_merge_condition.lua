-- Test 4449: CTE - CTE columns in MERGE condition

return {
  number = 4449,
  description = "CTE - CTE columns in MERGE condition",
  database = "vim_dadbod_test",
  query = [[WITH SourceCTE AS (SELECT EmployeeID, FirstName, Salary FROM Employees WHERE DepartmentID = 1)
MERGE INTO Employees AS target
USING SourceCTE AS source
ON target.EmployeeID = source.█]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
