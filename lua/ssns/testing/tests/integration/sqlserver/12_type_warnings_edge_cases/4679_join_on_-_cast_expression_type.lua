-- Test 4679: JOIN ON - CAST expression type

return {
  number = 4679,
  description = "JOIN ON - CAST expression type",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Orders o ON CAST(e.EmployeeID AS VARCHAR(10)) = o.OrderId█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
