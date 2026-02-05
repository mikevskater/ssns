-- Test 4643: MERGE - HOLDLOCK hint

return {
  number = 4643,
  description = "MERGE - HOLDLOCK hint",
  database = "vim_dadbod_test",
  query = [[MERGE INTO Employees WITH (HOLDLOCK) AS target
USING (SELECT * FROM Employees WHERE DepartmentID = 1) AS source
ON target.█ = source.EmployeeID]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
