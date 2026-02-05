-- Test 4602: DELETE - table completion after DELETE (no FROM)

return {
  number = 4602,
  description = "DELETE - table completion after DELETE (no FROM)",
  database = "vim_dadbod_test",
  query = "DELETE █",
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
