-- Test 4650: MERGE - complete statement column reference

return {
  number = 4650,
  description = "MERGE - complete statement column reference",
  database = "vim_dadbod_test",
  skip = false,
  query = [[MERGE INTO Employees AS target
USING (SELECT * FROM Employees WHERE DepartmentID = 1) AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED THEN
  UPDATE SET
    target.FirstName = source.FirstName,
    target.LastName = source.LastName,
    target.Salary = source.Salary,
    target.DepartmentID = source.█
WHEN NOT MATCHED THEN
  INSERT (EmployeeID, FirstName, LastName)
  VALUES (source.EmployeeID, source.FirstName, source.LastName)]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
