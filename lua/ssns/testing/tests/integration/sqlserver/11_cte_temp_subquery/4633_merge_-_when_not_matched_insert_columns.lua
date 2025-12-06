-- Test 4633: MERGE - WHEN NOT MATCHED INSERT columns
-- SKIPPED: MERGE INSERT column completion not yet supported

return {
  number = 4633,
  description = "MERGE - WHEN NOT MATCHED INSERT columns",
  database = "vim_dadbod_test",
  skip = false,
  query = [[MERGE INTO Employees AS target
USING (SELECT * FROM Employees WHERE DepartmentID = 1) AS source
ON target.EmployeeID = source.EmployeeID
WHEN NOT MATCHED THEN INSERT (█) VALUES (source.EmployeeID)]],
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
