-- Test 4192: ORDER BY - with prefix

return {
  number = 4192,
  description = "ORDER BY - with prefix",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees ORDER BY First█",
  expected = {
    items = {
      includes = {
        "FirstName",
      },
    },
    type = "column",
  },
}
