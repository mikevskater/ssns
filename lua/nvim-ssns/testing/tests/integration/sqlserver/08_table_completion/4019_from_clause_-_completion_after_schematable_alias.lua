-- Test 4019: FROM clause - completion after schema.table alias

return {
  number = 4019,
  description = "FROM clause - completion after schema.table alias",
  database = "vim_dadbod_test",
  query = "SELECT * FROM dbo.Employees e, █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
