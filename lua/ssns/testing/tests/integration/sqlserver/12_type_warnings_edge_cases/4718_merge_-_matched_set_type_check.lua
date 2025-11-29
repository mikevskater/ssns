-- Test 4718: MERGE - matched SET type check

return {
  number = 4718,
  description = "MERGE - matched SET type check",
  database = "vim_dadbod_test",
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
