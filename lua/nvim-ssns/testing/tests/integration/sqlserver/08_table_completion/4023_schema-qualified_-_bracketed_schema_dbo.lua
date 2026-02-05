-- Test 4023: Schema-qualified - bracketed schema [dbo].

return {
  number = 4023,
  description = "Schema-qualified - bracketed schema [dbo].",
  database = "vim_dadbod_test",
  query = "SELECT * FROM [dbo].█",
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
