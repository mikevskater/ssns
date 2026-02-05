-- Test 4028: Schema-qualified - second table in FROM

return {
  number = 4028,
  description = "Schema-qualified - second table in FROM",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e, dbo.█",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
