-- Test 4332: Alias generation - avoids conflict with existing 'd'

return {
  number = 4332,
  description = "Alias generation - avoids conflict with existing 'd'",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e, Products d JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "join_suggestion",
  },
}
