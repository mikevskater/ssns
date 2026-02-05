-- Test 4096: DELETE FROM - with alias

return {
  number = 4096,
  description = "DELETE FROM - with alias",
  database = "vim_dadbod_test",
  query = "DELETE e FROM █",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
