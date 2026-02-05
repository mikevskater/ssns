-- Test 4067: JOIN - CROSS JOIN table completion

return {
  number = 4067,
  description = "JOIN - CROSS JOIN table completion",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e CROSS JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
