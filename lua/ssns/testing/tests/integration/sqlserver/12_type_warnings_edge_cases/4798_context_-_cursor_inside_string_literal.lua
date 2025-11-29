-- Test 4798: Context - cursor inside string literal

return {
  number = 4798,
  description = "Context - cursor inside string literal",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE FirstName = 'Jo█'",
  expected = {
    type = "none",
  },
}
