-- Test 4721: Edge case - table with spaces in name

return {
  number = 4721,
  description = "Edge case - table with spaces in name",
  database = "vim_dadbod_test",
  query = "SELECT * FROM [Table With Spaces] █",
  expected = {
    items = {
      valid = true,
    },
    type = "valid",
  },
}
