-- Test 4302: FK suggestion - Orders -> Customers (1 hop)

return {
  number = 4302,
  description = "FK suggestion - Orders -> Customers (1 hop)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN █",
  expected = {
    items = {
      includes = {
        "Customers",
      },
    },
    type = "join_suggestion",
  },
}
