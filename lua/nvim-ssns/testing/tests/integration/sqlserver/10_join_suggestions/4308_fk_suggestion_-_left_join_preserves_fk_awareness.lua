-- Test 4308: FK suggestion - LEFT JOIN preserves FK awareness

return {
  number = 4308,
  description = "FK suggestion - LEFT JOIN preserves FK awareness",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e LEFT JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "join_suggestion",
  },
}
