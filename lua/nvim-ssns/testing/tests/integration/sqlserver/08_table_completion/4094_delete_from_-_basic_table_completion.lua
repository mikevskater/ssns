-- Test 4094: DELETE FROM - basic table completion

return {
  number = 4094,
  description = "DELETE FROM - basic table completion",
  database = "vim_dadbod_test",
  query = "DELETE FROM █",
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
