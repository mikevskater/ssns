-- Test 4739: Edge case - newline in middle of identifier (error)

return {
  number = 4739,
  description = "Edge case - newline in middle of identifier (error)",
  database = "vim_dadbod_test",
  query = [[SELECT First█
Name FROM Employees]],
  expected = {
    type = "error",
  },
}
