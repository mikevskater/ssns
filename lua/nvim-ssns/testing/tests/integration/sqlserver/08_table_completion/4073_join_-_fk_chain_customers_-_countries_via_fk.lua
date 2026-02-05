-- Test 4073: JOIN - FK chain: Customers -> Countries (via FK)

return {
  number = 4073,
  description = "JOIN - FK chain: Customers -> Countries (via FK)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Customers c JOIN █",
  expected = {
    items = {
      includes = {
        "Countries",
      },
    },
    type = "join_suggestion",
  },
}
