-- Test 4778: Error - DELETE with invalid syntax

return {
  number = 4778,
  description = "Error - DELETE with invalid syntax",
  database = "vim_dadbod_test",
  query = "DELETE Employees SET█",
  expected = {
    type = "error",
  },
}
