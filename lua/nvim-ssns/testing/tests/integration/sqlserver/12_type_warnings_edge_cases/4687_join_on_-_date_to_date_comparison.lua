-- Test 4687: JOIN ON - date to date comparison

return {
  number = 4687,
  description = "JOIN ON - date to date comparison",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN Projects p ON o.OrderDate = p.StartDate█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
