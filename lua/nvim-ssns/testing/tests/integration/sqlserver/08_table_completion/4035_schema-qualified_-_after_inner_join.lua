-- Test 4035: Schema-qualified - after INNER JOIN

return {
  number = 4035,
  description = "Schema-qualified - after INNER JOIN",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e INNER JOIN dbo.█",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
