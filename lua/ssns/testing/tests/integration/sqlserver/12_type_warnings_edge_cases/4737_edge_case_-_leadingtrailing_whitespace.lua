-- Test 4737: Edge case - leading/trailing whitespace

return {
  number = 4737,
  description = "Edge case - leading/trailing whitespace",
  database = "vim_dadbod_test",
  query = "SELECT   FirstName   ,   LastName  █ FROM   Employees",
  expected = {
    items = {
      valid = true,
    },
    type = "valid",
  },
}
