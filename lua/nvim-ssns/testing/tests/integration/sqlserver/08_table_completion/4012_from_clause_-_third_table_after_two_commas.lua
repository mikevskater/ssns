-- Test 4012: FROM clause - third table after two commas

return {
  number = 4012,
  description = "FROM clause - third table after two commas",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees, Departments, █",
  expected = {
    items = {
      includes = {
        "Projects",
        "Orders",
      },
    },
    type = "table",
  },
}
