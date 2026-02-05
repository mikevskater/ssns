-- Test 4649: MERGE - WHEN clause with AND condition

return {
  number = 4649,
  description = "MERGE - WHEN clause with AND condition",
  database = "vim_dadbod_test",
  skip = false,
  query = [[MERGE INTO Employees AS target
USING (SELECT * FROM Employees WHERE DepartmentID = 1) AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED AND source.█ = 0 THEN DELETE]],
  expected = {
    items = {
      includes = {
        "IsActive",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
