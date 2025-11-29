-- Test 4765: Error - syntax error before cursor

return {
  number = 4765,
  description = "Error - syntax error before cursor",
  database = "vim_dadbod_test",
  query = "SELECT * FORM Employees WHERE █",
  expected = {
    type = "error",
  },
}
