-- Test 4196: ORDER BY - after DESC

return {
  number = 4196,
  description = "ORDER BY - after DESC",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees ORDER BY LastName DESC, █",
  expected = {
    items = {
      includes = {
        "FirstName",
      },
    },
    type = "column",
  },
}
