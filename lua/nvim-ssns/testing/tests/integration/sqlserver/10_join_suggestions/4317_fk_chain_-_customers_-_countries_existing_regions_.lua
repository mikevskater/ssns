-- Test 4317: FK chain - Customers -> Countries (existing) + Regions (2 hop)

return {
  number = 4317,
  description = "FK chain - Customers -> Countries (existing) + Regions (2 hop)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Customers c JOIN Countries co ON c.CountryID = co.CountryID JOIN█ ",
  expected = {
    items = {
      includes = {
        "Regions",
      },
    },
    type = "join_suggestion",
  },
}
