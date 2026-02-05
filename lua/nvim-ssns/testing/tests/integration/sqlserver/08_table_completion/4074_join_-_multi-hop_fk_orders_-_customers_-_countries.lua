-- Test 4074: JOIN - multi-hop FK: Orders -> Customers -> Countries

return {
  number = 4074,
  description = "JOIN - multi-hop FK: Orders -> Customers -> Countries",
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
