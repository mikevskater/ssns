-- Test 4557: INSERT - SELECT with explicit columns

return {
  number = 4557,
  description = "INSERT - SELECT with explicit columns",
  database = "vim_dadbod_test",
  query = [[INSERT INTO Employees_Archive (ID, Name)
SELECT EmployeeID, █ FROM Employees]],
  expected = {
    items = {
      includes = {
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
