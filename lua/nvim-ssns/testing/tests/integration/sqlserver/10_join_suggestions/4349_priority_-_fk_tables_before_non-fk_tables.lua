-- Test 4349: Priority - FK tables before non-FK tables

return {
  number = 4349,
  description = "Priority - FK tables before non-FK tables",
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
