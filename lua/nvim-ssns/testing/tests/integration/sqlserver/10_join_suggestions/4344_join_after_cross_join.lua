-- Test 4344: JOIN after CROSS JOIN

return {
  number = 4344,
  description = "JOIN after CROSS JOIN",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e CROSS JOIN Departments d JOIN█ ",
  expected = {
    items = {
      includes = {
        "Projects",
      },
    },
    type = "table",
  },
}
