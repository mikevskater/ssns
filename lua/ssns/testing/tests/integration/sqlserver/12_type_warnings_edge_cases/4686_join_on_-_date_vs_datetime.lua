-- Test 4686: JOIN ON - date vs datetime

return {
  number = 4686,
  description = "JOIN ON - date vs datetime",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN Customers c ON o.OrderDate = c.CreatedDate█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
