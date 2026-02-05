-- Test 4314: FK suggestion - FK priority over non-FK tables

return {
  number = 4314,
  description = "FK suggestion - FK priority over non-FK tables",
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
