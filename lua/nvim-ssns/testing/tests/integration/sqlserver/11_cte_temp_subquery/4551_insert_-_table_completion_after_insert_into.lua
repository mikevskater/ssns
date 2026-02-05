-- Test 4551: INSERT - table completion after INSERT INTO

return {
  number = 4551,
  description = "INSERT - table completion after INSERT INTO",
  database = "vim_dadbod_test",
  query = "INSERT INTO █",
  expected = {
    items = {
      includes = {
        "Employees",
        "Departments",
        "Projects",
      },
    },
    type = "table",
  },
}
