-- Test 4635: MERGE - WHEN NOT MATCHED BY SOURCE DELETE
-- SKIPPED: MERGE target column completion in WHEN clause not yet supported

return {
  number = 4635,
  description = "MERGE - WHEN NOT MATCHED BY SOURCE DELETE",
  database = "vim_dadbod_test",
  skip = false,
  query = [[MERGE INTO Employees AS target
USING (SELECT * FROM Employees WHERE DepartmentID = 1) AS source
ON target.EmployeeID = source.EmployeeID
WHEN MATCHED THEN UPDATE SET target.FirstName = source.FirstName
WHEN NOT MATCHED BY SOURCE AND target.█ < GETDATE() THEN DELETE]],
  expected = {
    items = {
      includes = {
        "HireDate",
      },
    },
    type = "column",
  },
}
