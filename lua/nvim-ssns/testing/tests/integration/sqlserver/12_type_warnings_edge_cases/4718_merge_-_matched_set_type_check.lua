-- Test 4718: MERGE - matched SET type check
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4718,
  description = "MERGE - matched SET type check",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
  query = "MERGE INTO Employees AS t USING (SELECT EmployeeID, FirstName FROM Employees) AS s ON t.EmployeeID = s.EmployeeID WHEN MATCHED THEN UPDATE SET t.Salary = s.█FirstName",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
