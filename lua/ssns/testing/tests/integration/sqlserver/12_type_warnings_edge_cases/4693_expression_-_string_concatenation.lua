-- Test 4693: Expression - string concatenation

return {
  number = 4693,
  description = "Expression - string concatenation",
  database = "vim_dadbod_test",
  query = "SELECT FirstName + ' ' + LastName F█ROM Employees",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
