-- Test 4738: Edge case - tab character as whitespace

return {
  number = 4738,
  description = "Edge case - tab character as whitespace",
  database = "vim_dadbod_test",
  query = "SELECT\9FirstName\9FROM█\9Employees",
  expected = {
    items = {
      valid = true,
    },
    type = "valid",
  },
}
