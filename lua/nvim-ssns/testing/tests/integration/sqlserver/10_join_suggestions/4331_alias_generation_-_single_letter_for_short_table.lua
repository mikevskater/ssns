-- Test 4331: Alias generation - single letter for short table

return {
  number = 4331,
  description = "Alias generation - single letter for short table",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "join_suggestion",
  },
}
