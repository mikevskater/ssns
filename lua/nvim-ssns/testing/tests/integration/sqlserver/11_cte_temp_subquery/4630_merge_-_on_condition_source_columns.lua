-- Test 4630: MERGE - ON condition source columns

return {
  number = 4630,
  description = "MERGE - ON condition source columns",
  database = "vim_dadbod_test",
  skip = false,
  query = [[MERGE INTO Employees AS target
USING (SELECT * FROM Employees WHERE DepartmentID = 1) AS source
ON target.EmployeeID = source.█]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
