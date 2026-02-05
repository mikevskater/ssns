-- Test 4601: DELETE - table completion after DELETE FROM

return {
  number = 4601,
  description = "DELETE - table completion after DELETE FROM",
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
