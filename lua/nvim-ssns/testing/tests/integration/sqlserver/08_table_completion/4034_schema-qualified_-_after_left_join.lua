-- Test 4034: Schema-qualified - after LEFT JOIN

return {
  number = 4034,
  description = "Schema-qualified - after LEFT JOIN",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e LEFT JOIN dbo.█",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
