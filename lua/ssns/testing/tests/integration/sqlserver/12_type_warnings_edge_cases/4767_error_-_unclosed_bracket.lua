-- Test 4767: Error - unclosed bracket

return {
  number = 4767,
  description = "Error - unclosed bracket",
  database = "vim_dadbod_test",
  query = "SELECT * FROM [Employees WHERE █",
  expected = {
    type = "error",
  },
}
