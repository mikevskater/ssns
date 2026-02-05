-- Test 4554: INSERT - column list with partial

return {
  number = 4554,
  description = "INSERT - column list with partial",
  database = "vim_dadbod_test",
  query = "INSERT INTO Employees (EmployeeID, █) VALUES (1, 'John')",
  expected = {
    items = {
      includes = {
        "FirstName",
        "LastName",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
