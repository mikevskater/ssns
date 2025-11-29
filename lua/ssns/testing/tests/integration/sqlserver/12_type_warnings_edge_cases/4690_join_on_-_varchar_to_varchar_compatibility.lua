-- Test 4690: JOIN ON - varchar to varchar compatibility

return {
  number = 4690,
  description = "JOIN ON - varchar to varchar compatibility",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Customers c JOIN Products p ON c.CustomerId = p.ProductId█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
