-- Test 4036: Schema-qualified - with bracketed table names

return {
  number = 4036,
  description = "Schema-qualified - with bracketed table names",
  database = "vim_dadbod_test",
  query = "SELECT * FROM dbo.[Emp█",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
