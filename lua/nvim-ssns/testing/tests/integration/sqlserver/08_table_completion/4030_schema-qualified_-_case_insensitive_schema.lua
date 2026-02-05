-- Test 4030: Schema-qualified - case insensitive schema

return {
  number = 4030,
  description = "Schema-qualified - case insensitive schema",
  database = "vim_dadbod_test",
  query = "SELECT * FROM DBO.█",
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
