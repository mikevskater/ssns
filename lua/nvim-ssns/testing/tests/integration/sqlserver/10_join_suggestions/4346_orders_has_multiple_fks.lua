-- Test 4346: Orders has multiple FKs

return {
  number = 4346,
  description = "Orders has multiple FKs",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN █",
  expected = {
    items = {
      includes = {
        "Customers",
        "Employees",
      },
    },
    type = "join_suggestion",
  },
}
