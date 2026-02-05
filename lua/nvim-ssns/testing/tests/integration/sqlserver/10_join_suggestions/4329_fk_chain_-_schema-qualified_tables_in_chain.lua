-- Test 4329: FK chain - schema-qualified tables in chain

return {
  number = 4329,
  description = "FK chain - schema-qualified tables in chain",
  database = "vim_dadbod_test",
  query = "SELECT * FROM dbo.Orders o JOIN dbo.Customers c ON o.CustomerId = c.Id JOIN█ ",
  expected = {
    items = {
      includes = {
        "Countries",
      },
    },
    type = "join_suggestion",
  },
}
