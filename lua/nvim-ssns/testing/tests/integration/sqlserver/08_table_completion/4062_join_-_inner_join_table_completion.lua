-- Test 4062: JOIN - INNER JOIN table completion

return {
  number = 4062,
  description = "JOIN - INNER JOIN table completion",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e INNER JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
