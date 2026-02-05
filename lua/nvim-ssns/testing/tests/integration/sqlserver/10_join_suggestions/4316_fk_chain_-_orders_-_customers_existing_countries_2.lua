-- Test 4316: FK chain - Orders -> Customers (existing) + Countries (2 hop)

return {
  number = 4316,
  description = "FK chain - Orders -> Customers (existing) + Countries (2 hop)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN Customers c ON o.CustomerId = c.Id JOIN █",
  expected = {
    items = {
      includes = {
        "Countries",
        "Employees",
      },
    },
    type = "join_suggestion",
  },
}
