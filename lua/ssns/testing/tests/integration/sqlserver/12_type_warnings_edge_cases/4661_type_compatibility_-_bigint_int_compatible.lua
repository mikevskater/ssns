-- Test 4661: Type compatibility - bigint = int (compatible)

return {
  number = 4661,
  description = "Type compatibility - bigint = int (compatible)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN Employees e ON o.OrderID = e.Employee█ID",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
