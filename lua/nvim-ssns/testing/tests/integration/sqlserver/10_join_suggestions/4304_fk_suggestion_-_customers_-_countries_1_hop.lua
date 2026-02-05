-- Test 4304: FK suggestion - Customers -> Countries (1 hop)

return {
  number = 4304,
  description = "FK suggestion - Customers -> Countries (1 hop)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Customers c JOIN █",
  expected = {
    items = {
      includes = {
        "Countries",
      },
    },
    type = "join_suggestion",
  },
}
