-- Test 4193: ORDER BY - alias-qualified

return {
  number = 4193,
  description = "ORDER BY - alias-qualified",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e ORDER BY e.█",
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
