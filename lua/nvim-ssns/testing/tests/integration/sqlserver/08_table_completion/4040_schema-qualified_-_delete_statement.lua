-- Test 4040: Schema-qualified - DELETE statement

return {
  number = 4040,
  description = "Schema-qualified - DELETE statement",
  database = "vim_dadbod_test",
  query = "DELETE FROM dbo.█",
  expected = {
    items = {
      includes = {
        "Employees",
        "Departments",
      },
    },
    type = "table",
  },
}
