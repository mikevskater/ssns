-- Test 4347: FK with same column names

return {
  number = 4347,
  description = "FK with same column names",
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
