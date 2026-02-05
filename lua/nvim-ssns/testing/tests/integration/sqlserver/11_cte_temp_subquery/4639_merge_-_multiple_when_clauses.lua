-- Test 4639: MERGE - multiple WHEN clauses

return {
  number = 4639,
  description = "MERGE - multiple WHEN clauses",
  database = "vim_dadbod_test",
  query = [[MERGE INTO Employees AS target
USING (SELECT * FROM Employees WHERE DepartmentID = 1) AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED AND source.IsActive = 0 THEN DELETE
WHEN MATCHED THEN UPDATE SET target.█= source.FirstName
WHEN NOT MATCHED THEN INSERT (EmployeeID) VALUES (source.EmployeeID)]],
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
