-- Test 4061: JOIN - basic table completion after JOIN

return {
  number = 4061,
  description = "JOIN - basic table completion after JOIN",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN █",
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
