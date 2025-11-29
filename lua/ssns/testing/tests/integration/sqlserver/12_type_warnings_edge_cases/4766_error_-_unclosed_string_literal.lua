-- Test 4766: Error - unclosed string literal

return {
  number = 4766,
  description = "Error - unclosed string literal",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE FirstName = 'John█",
  expected = {
    type = "error",
  },
}
