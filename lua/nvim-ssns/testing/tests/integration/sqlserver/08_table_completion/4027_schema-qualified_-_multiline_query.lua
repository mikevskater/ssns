-- Test 4027: Schema-qualified - multiline query

return {
  number = 4027,
  description = "Schema-qualified - multiline query",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM dbo.█]],
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
