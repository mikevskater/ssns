-- Test 4688: JOIN ON - varchar compatibility

return {
  number = 4688,
  description = "JOIN ON - varchar compatibility",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Customers c ON e.Email = c.Email█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
