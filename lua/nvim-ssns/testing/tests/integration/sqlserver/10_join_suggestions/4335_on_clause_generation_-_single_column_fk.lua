-- Test 4335: ON clause generation - single column FK
-- Tests that Departments FK suggestion works for single column FK

return {
  number = 4335,
  description = "ON clause generation - single column FK",
  database = "vim_dadbod_test",
  skip = false,
  query = "SELECT * FROM Employees e JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "join_suggestion",
  },
}
