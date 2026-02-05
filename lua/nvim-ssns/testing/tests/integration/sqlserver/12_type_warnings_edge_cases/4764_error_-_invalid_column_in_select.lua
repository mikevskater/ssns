-- Test 4764: Error - invalid column in SELECT

return {
  number = 4764,
  description = "Error - invalid column in SELECT",
  database = "vim_dadbod_test",
  query = "SELECT NonExistentColumn, █ FROM Employees",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
