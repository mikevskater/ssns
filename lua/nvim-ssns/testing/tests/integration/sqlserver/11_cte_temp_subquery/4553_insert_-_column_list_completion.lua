-- Test 4553: INSERT - column list completion

return {
  number = 4553,
  description = "INSERT - column list completion",
  database = "vim_dadbod_test",
  query = "INSERT INTO Employees █() VALUES (1, 'John', 'Doe')",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
        "LastName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
