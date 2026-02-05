-- Test 4672: JOIN ON - varchar to int conversion (warning)
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4672,
  description = "JOIN ON - varchar to int conversion (warning)",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
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
