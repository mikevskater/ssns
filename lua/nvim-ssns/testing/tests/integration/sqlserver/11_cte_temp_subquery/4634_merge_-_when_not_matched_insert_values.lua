-- Test 4634: MERGE - WHEN NOT MATCHED INSERT VALUES

return {
  number = 4634,
  description = "MERGE - WHEN NOT MATCHED INSERT VALUES",
  database = "vim_dadbod_test",
  skip = false,
  query = [[MERGE INTO Employees AS target
USING (SELECT * FROM Employees WHERE DepartmentID = 1) AS source
ON target.EmployeeID = source.EmployeeID
WHEN NOT MATCHED THEN INSERT (EmployeeID, FirstName) VALUES (source.EmployeeID, source.█)]],
  expected = {
    items = {
      includes = {
        "FirstName",
      },
    },
    type = "column",
  },
}
