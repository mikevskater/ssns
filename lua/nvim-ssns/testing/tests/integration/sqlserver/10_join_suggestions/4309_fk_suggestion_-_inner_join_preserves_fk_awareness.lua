-- Test 4309: FK suggestion - INNER JOIN preserves FK awareness

return {
  number = 4309,
  description = "FK suggestion - INNER JOIN preserves FK awareness",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e INNER JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "join_suggestion",
  },
}
