-- Test 4363: ON clause - suggest Id based on CustomerId context

return {
  number = 4363,
  description = "ON clause - suggest Id based on CustomerId context",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN Customers c ON o.CustomerId = c.█",
  expected = {
    items = {
      includes = {
        "Id",
        "CustomerId",
      },
    },
    type = "column",
  },
}
