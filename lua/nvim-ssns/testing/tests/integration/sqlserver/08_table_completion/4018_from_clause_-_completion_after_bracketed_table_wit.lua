-- Test 4018: FROM clause - completion after bracketed table with alias

return {
  number = 4018,
  description = "FROM clause - completion after bracketed table with alias",
  database = "vim_dadbod_test",
  query = "SELECT * FROM [Employees] e, █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
