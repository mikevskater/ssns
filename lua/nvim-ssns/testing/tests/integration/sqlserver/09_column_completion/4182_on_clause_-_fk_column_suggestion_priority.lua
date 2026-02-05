-- Test 4182: ON clause - FK column suggestion priority

return {
  number = 4182,
  description = "ON clause - FK column suggestion priority",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN Customers c ON o.CustomerId = c.█",
  expected = {
    items = {
      includes = {
        "Id",
      },
    },
    type = "column",
  },
}
