-- Test 4322: FK chain - 2-hop suggestions show via indicator

return {
  number = 4322,
  description = "FK chain - 2-hop suggestions show via indicator",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN █",
  expected = {
    items = {
      includes = {
        "Countries",
      },
    },
    type = "join_suggestion",
  },
}
