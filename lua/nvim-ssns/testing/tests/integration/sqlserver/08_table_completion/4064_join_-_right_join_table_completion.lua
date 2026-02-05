-- Test 4064: JOIN - RIGHT JOIN table completion

return {
  number = 4064,
  description = "JOIN - RIGHT JOIN table completion",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e RIGHT JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
