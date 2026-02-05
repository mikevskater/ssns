-- Test 4323: FK chain - skip already joined tables
-- SKIPPED: FK chain skip already joined tables not yet supported

return {
  number = 4323,
  description = "FK chain - skip already joined tables",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "FK chain skip already joined tables not yet supported",
  query = "SELECT * FROM Orders o JOIN Customers c ON o.CustomerId = c.Id JOIN █",
  expected = {
    items = {
      excludes = {
        "Customers",
      },
      includes = {
        "Countries",
      },
    },
    type = "join_suggestion",
  },
}
