-- Test 4684: JOIN ON - int to int consistency

return {
  number = 4684,
  description = "JOIN ON - int to int consistency",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Customers c1 JOIN Customers c2 ON c1.CountryID = c2.CountryID█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
