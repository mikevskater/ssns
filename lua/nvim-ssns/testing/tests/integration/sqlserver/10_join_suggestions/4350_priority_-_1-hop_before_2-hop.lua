-- Test 4350: Priority - 1-hop before 2-hop

return {
  number = 4350,
  description = "Priority - 1-hop before 2-hop",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN █",
  expected = {
    items = {
      includes = {
        "Customers",
        "Countries",
      },
    },
    type = "join_suggestion",
  },
}
