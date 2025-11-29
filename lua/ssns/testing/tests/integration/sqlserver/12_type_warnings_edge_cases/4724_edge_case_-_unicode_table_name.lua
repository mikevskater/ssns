-- Test 4724: Edge case - Unicode table name

return {
  number = 4724,
  description = "Edge case - Unicode table name",
  database = "vim_dadbod_test",
  query = "SELECT * FROM [テーブル] █",
  expected = {
    items = {
      valid = true,
    },
    type = "valid",
  },
}
