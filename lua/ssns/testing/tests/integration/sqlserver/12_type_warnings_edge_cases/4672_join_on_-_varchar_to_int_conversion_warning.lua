-- Test 4672: JOIN ON - varchar to int conversion (warning)

return {
  number = 4672,
  description = "JOIN ON - varchar to int conversion (warning)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN Employees e ON o.OrderId = e.EmployeeID█",
  expected = {
    items = {
      includes_any = {
        "implicit_conversion",
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
