-- Test 4333: Alias generation - multiple conflicting aliases

return {
  number = 4333,
  description = "Alias generation - multiple conflicting aliases",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e, Products d, Projects de JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "join_suggestion",
  },
}
