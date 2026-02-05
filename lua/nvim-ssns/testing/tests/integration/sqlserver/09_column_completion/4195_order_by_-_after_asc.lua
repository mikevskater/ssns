-- Test 4195: ORDER BY - after ASC

return {
  number = 4195,
  description = "ORDER BY - after ASC",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees ORDER BY LastName ASC, █",
  expected = {
    items = {
      includes = {
        "FirstName",
      },
    },
    type = "column",
  },
}
