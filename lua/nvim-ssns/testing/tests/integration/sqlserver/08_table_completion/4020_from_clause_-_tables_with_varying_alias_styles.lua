-- Test 4020: FROM clause - tables with varying alias styles

return {
  number = 4020,
  description = "FROM clause - tables with varying alias styles",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees emp, Departments AS dept, █",
  expected = {
    items = {
      includes = {
        "Projects",
      },
    },
    type = "table",
  },
}
