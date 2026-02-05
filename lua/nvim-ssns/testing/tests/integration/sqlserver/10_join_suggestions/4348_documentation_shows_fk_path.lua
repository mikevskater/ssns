-- Test 4348: Documentation shows FK path

return {
  number = 4348,
  description = "Documentation shows FK path",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Orders o JOIN █",
  expected = {
    items = {
      includes = {
        "Customers",
      },
    },
    type = "join_suggestion",
  },
}
