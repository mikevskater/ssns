-- Test 4629: MERGE - ON condition target columns

return {
  number = 4629,
  description = "MERGE - ON condition target columns",
  database = "vim_dadbod_test",
  query = [[MERGE INTO Employees AS target
USING (SELECT * FROM Employees WHERE DepartmentID = 1) AS source
ON target.█]],
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
