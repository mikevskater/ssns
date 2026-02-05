-- Test 4103: SELECT - columns after existing column

return {
  number = 4103,
  description = "SELECT - columns after existing column",
  database = "vim_dadbod_test",
  query = "SELECT EmployeeID, █ FROM Employees",
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
