-- Test 4310: FK suggestion - RIGHT JOIN preserves FK awareness

return {
  number = 4310,
  description = "FK suggestion - RIGHT JOIN preserves FK awareness",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e RIGHT JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "join_suggestion",
  },
}
