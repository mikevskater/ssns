-- Test 4194: ORDER BY - second column after comma

return {
  number = 4194,
  description = "ORDER BY - second column after comma",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees ORDER BY LastName, █",
  expected = {
    items = {
      includes = {
        "FirstName",
        "EmployeeID",
      },
    },
    type = "column",
  },
}
