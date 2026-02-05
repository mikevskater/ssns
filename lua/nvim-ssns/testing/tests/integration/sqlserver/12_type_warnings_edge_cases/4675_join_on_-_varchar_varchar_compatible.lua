-- Test 4675: JOIN ON - varchar = varchar (compatible)

return {
  number = 4675,
  description = "JOIN ON - varchar = varchar (compatible)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Customers c JOIN Countries co ON c.Country = co.CountryName█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
