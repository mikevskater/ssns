-- Test 4632: MERGE - WHEN MATCHED UPDATE source column

return {
  number = 4632,
  description = "MERGE - WHEN MATCHED UPDATE source column",
  database = "vim_dadbod_test",
  skip = false,
  query = [[MERGE INTO Employees AS target
USING (SELECT * FROM Employees WHERE DepartmentID = 1) AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED THEN UPDATE SET target.FirstName = source.█]],
  expected = {
    items = {
      includes = {
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
