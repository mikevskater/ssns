-- Test 4065: JOIN - FULL OUTER JOIN table completion

return {
  number = 4065,
  description = "JOIN - FULL OUTER JOIN table completion",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e FULL OUTER JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
