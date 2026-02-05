-- Test 4305: FK suggestion - Countries -> Regions (1 hop)

return {
  number = 4305,
  description = "FK suggestion - Countries -> Regions (1 hop)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Countries c JOIN █",
  expected = {
    items = {
      includes = {
        "Regions",
      },
    },
    type = "join_suggestion",
  },
}
