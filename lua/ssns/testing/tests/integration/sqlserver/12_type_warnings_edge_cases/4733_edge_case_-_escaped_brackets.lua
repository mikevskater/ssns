-- Test 4733: Edge case - escaped brackets

return {
  number = 4733,
  description = "Edge case - escaped brackets",
  database = "vim_dadbod_test",
  query = "SELECT * FROM [Table] ]With█]]Brackets] ",
  expected = {
    items = {
      valid = true,
    },
    type = "valid",
  },
}
