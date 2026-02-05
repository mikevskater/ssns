-- Test 4081: INSERT INTO - basic table completion

return {
  number = 4081,
  description = "INSERT INTO - basic table completion",
  database = "vim_dadbod_test",
  query = "INSERT INTO █",
  expected = {
    items = {
      excludes = {
      },
      includes = {
        "Employees",
        "Departments",
        "Projects",
      },
    },
    type = "table",
  },
}
