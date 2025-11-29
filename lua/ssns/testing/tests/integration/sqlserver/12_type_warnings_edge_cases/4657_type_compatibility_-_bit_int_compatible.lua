-- Test 4657: Type compatibility - bit = int (compatible)

return {
  number = 4657,
  description = "Type compatibility - bit = int (compatible)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE IsActive = 1█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
