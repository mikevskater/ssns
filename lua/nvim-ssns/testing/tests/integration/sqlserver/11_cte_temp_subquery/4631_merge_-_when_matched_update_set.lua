-- Test 4631: MERGE - WHEN MATCHED UPDATE SET

return {
  number = 4631,
  description = "MERGE - WHEN MATCHED UPDATE SET",
  database = "vim_dadbod_test",
  query = [[MERGE INTO Employees AS target
USING (SELECT * FROM Employees WHERE DepartmentID = 1) AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED THEN UPDATE SET target.█= source.FirstName]],
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
