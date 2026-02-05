-- Test 4017: FROM clause - completion after table with AS alias

return {
  number = 4017,
  description = "FROM clause - completion after table with AS alias",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees AS e, █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
