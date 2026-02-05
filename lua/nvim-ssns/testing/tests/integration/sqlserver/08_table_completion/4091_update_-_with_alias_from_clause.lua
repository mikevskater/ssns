-- Test 4091: UPDATE - with alias (FROM clause)

return {
  number = 4091,
  description = "UPDATE - with alias (FROM clause)",
  database = "vim_dadbod_test",
  query = "UPDATE e SET Name = 'Test' FROM █",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
