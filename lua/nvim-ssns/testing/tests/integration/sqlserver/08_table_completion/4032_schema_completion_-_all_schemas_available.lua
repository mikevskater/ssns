-- Test 4032: Schema completion - all schemas available

return {
  number = 4032,
  description = "Schema completion - all schemas available",
  database = "vim_dadbod_test",
  query = "SELECT * FROM █",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
