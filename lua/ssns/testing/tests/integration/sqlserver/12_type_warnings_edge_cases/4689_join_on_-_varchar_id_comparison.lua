-- Test 4689: JOIN ON - varchar id comparison

return {
  number = 4689,
  description = "JOIN ON - varchar id comparison",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN Products p ON o.OrderId = p.ProductId█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
