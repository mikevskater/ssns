-- Test 4709: Expression - SUBSTRING on varchar

return {
  number = 4709,
  description = "Expression - SUBSTRING on varchar",
  database = "vim_dadbod_test",
  query = "SELECT SUBSTRING(FirstName, 1, 3) █FROM Employees",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
