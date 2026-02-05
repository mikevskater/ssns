-- Test 4097: DELETE - without FROM keyword

return {
  number = 4097,
  description = "DELETE - without FROM keyword",
  database = "vim_dadbod_test",
  query = "DELETE █",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
