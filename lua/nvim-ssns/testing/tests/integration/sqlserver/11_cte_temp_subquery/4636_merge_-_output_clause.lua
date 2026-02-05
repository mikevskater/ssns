-- Test 4636: MERGE - OUTPUT clause
-- SKIPPED: OUTPUT clause column completion not yet supported

return {
  number = 4636,
  description = "MERGE - OUTPUT clause",
  database = "vim_dadbod_test",
  skip = false,
  query = [[MERGE INTO Employees AS target
USING (SELECT * FROM Employees WHERE DepartmentID = 1) AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED THEN UPDATE SET target.FirstName = source.FirstName
OUTPUT $action, inserted.█, deleted.EmployeeID]],
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
