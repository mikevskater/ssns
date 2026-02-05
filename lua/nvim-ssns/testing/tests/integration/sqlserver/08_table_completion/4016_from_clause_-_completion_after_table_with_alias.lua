-- Test 4016: FROM clause - completion after table with alias

return {
  number = 4016,
  description = "FROM clause - completion after table with alias",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e, █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
