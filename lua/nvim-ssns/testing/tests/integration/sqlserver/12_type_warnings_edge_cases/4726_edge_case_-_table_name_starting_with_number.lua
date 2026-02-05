-- Test 4726: Edge case - table name starting with number

return {
  number = 4726,
  description = "Edge case - table name starting with number",
  database = "vim_dadbod_test",
  query = "SELECT * FROM [123Table]█ ",
  expected = {
    items = {
      valid = true,
    },
    type = "valid",
  },
}
