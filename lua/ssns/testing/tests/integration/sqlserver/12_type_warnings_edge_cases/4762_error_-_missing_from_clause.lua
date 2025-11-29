-- Test 4762: Error - missing FROM clause

return {
  number = 4762,
  description = "Error - missing FROM clause",
  database = "vim_dadbod_test",
  query = "SELECT EmployeeID█",
  expected = {
    items = {
      valid = true,
    },
    type = "valid",
  },
}
