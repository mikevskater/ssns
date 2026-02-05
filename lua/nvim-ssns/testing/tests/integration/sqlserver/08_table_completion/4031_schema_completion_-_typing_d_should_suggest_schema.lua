-- Test 4031: Schema completion - typing 'd' should suggest schemas

return {
  number = 4031,
  description = "Schema completion - typing 'd' should suggest schemas",
  database = "vim_dadbod_test",
  query = "SELECT * FROM d█",
  expected = {
    items = {
      includes = {
        "dbo",
        "Departments",
      },
    },
    type = "mixed",
  },
}
