-- Test 4334: Alias generation - case insensitive conflict check

return {
  number = 4334,
  description = "Alias generation - case insensitive conflict check",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees E JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "join_suggestion",
  },
}
