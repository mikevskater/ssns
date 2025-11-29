-- Test 4796: Context - block comment

return {
  number = 4796,
  description = "Context - block comment",
  database = "vim_dadbod_test",
  query = "/* Block comment */ SELECT █ FROM Employees",
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
