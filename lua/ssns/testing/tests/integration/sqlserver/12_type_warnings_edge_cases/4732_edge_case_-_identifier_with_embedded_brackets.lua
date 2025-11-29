-- Test 4732: Edge case - identifier with embedded brackets

return {
  number = 4732,
  description = "Edge case - identifier with embedded brackets",
  database = "vim_dadbod_test",
  query = "SELECT * FROM [Table[With]Brackets]█ ",
  expected = {
    type = "error",
  },
}
