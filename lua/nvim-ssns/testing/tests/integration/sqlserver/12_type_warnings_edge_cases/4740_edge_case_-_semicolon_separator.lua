-- Test 4740: Edge case - semicolon separator

return {
  number = 4740,
  description = "Edge case - semicolon separator",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees; SELECT * FROM █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
