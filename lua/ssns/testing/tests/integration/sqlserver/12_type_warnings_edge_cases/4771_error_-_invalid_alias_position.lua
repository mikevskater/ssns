-- Test 4771: Error - invalid alias position

return {
  number = 4771,
  description = "Error - invalid alias position",
  database = "vim_dadbod_test",
  query = "SELECT AS █alias FROM Employees",
  expected = {
    type = "error",
  },
}
