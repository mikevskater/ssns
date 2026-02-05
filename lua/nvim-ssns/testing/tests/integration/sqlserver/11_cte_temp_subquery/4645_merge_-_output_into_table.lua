-- Test 4645: MERGE - OUTPUT INTO table
-- SKIPPED: OUTPUT clause completion not yet supported

return {
  number = 4645,
  description = "MERGE - OUTPUT INTO table",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #MergeOutput (Action VARCHAR(10), EmployeeID INT)
MERGE INTO Employees AS target
USING (SELECT * FROM Employees WHERE DepartmentID = 1) AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED THEN UPDATE SET target.FirstName = source.FirstName
OUTPUT $action, inserted.EmployeeID INTO █]],
  expected = {
    items = {
      includes_any = {
        "Projects",
        "#MergeOutput",
      },
    },
    type = "table",
  },
}
