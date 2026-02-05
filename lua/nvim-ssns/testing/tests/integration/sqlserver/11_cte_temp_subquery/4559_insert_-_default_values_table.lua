-- Test 4559: INSERT - DEFAULT VALUES table

return {
  number = 4559,
  description = "INSERT - DEFAULT VALUES table",
  database = "vim_dadbod_test",
  query = "INSERT INTO █ DEFAULT VALUES",
  expected = {
    items = {
      includes = {
        "Employees",
        "Projects",
      },
    },
    type = "table",
  },
}
