-- Test 4336: ON clause generation - uses correct source alias
-- Tests that Departments FK suggestion works with custom alias

return {
  number = 4336,
  description = "ON clause generation - uses correct source alias",
  database = "vim_dadbod_test",
  skip = false,
  query = "SELECT * FROM Employees emp JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "join_suggestion",
  },
}
