-- Test 4011: FROM clause - second table after comma

return {
  number = 4011,
  description = "FROM clause - second table after comma",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees, █",
  expected = {
    items = {
      includes = {
        "Departments",
        "Projects",
      },
    },
    type = "table",
  },
}
