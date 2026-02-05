-- Test 4504: Subquery - table completion in FROM subquery

return {
  number = 4504,
  description = "Subquery - table completion in FROM subquery",
  database = "vim_dadbod_test",
  query = "SELECT * FROM (SELECT * FROM █) sub",
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
