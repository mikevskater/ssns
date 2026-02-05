-- Test 4708: Expression - string function on non-string

return {
  number = 4708,
  description = "Expression - string function on non-string",
  database = "vim_dadbod_test",
  query = "SELECT LEN(EmployeeID)█ FROM Employees",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
