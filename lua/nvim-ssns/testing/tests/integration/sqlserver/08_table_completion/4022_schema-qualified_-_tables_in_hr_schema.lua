-- Test 4022: Schema-qualified - tables in hr schema

return {
  number = 4022,
  description = "Schema-qualified - tables in hr schema",
  database = "vim_dadbod_test",
  query = "SELECT * FROM hr.█",
  expected = {
    items = {
      excludes = {
        "Employees",
        "Departments",
      },
      includes = {
        "Benefits",
      },
    },
    type = "table",
  },
}
