-- Test 4033: Schema-qualified - after JOIN keyword

return {
  number = 4033,
  description = "Schema-qualified - after JOIN keyword",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN dbo.█",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
