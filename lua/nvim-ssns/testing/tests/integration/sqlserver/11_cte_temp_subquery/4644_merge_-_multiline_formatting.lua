-- Test 4644: MERGE - multiline formatting

return {
  number = 4644,
  description = "MERGE - multiline formatting",
  database = "vim_dadbod_test",
  query = [[MERGE INTO Employees AS target
USING (SELECT * FROM Employees WHERE DepartmentID = 1) AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED THEN
  UPDATE SET
    target.FirstName = source.FirstName,
    target.█ = source.LastName]],
  expected = {
    items = {
      includes = {
        "LastName",
      },
    },
    type = "column",
  },
}
