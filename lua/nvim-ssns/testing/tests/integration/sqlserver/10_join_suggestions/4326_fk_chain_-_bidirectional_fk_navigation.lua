-- Test 4326: FK chain - bidirectional FK navigation

return {
  number = 4326,
  description = "FK chain - bidirectional FK navigation",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Departments d JOIN █",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "join_suggestion",
  },
}
