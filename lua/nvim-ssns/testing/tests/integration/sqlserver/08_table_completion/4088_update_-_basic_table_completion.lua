-- Test 4088: UPDATE - basic table completion

return {
  number = 4088,
  description = "UPDATE - basic table completion",
  database = "vim_dadbod_test",
  query = "UPDATE █",
  expected = {
    items = {
      includes = {
        "Employees",
        "Departments",
      },
    },
    type = "table",
  },
}
