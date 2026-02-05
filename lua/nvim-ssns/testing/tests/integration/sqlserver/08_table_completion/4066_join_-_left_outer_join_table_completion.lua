-- Test 4066: JOIN - LEFT OUTER JOIN table completion

return {
  number = 4066,
  description = "JOIN - LEFT OUTER JOIN table completion",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e LEFT OUTER JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
