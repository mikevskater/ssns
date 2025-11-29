-- Test 4677: JOIN ON - multiple compatible conditions

return {
  number = 4677,
  description = "JOIN ON - multiple compatible conditions",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN Products p ON o.Id = p.Id AND o.OrderId = p.ProductId█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
