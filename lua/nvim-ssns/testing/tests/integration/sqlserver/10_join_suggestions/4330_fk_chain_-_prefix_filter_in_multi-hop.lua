-- Test 4330: FK chain - prefix filter in multi-hop

return {
  number = 4330,
  description = "FK chain - prefix filter in multi-hop",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN Customers c ON o.CustomerId = c.Id JOIN Coun█",
  expected = {
    items = {
      includes = {
        "Countries",
      },
    },
    type = "join_suggestion",
  },
}
