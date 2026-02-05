-- Test 4063: JOIN - LEFT JOIN table completion

return {
  number = 4063,
  description = "JOIN - LEFT JOIN table completion",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e LEFT JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
