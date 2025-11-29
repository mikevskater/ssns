-- Test 4702: Expression - COUNT with any type

return {
  number = 4702,
  description = "Expression - COUNT with any type",
  database = "vim_dadbod_test",
  query = "SELECT COUNT(FirstName)█ FROM Employees",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
