-- Test 4700: Expression - aggregate with valid type

return {
  number = 4700,
  description = "Expression - aggregate with valid type",
  database = "vim_dadbod_test",
  query = "SELECT SUM(Salary)█ FROM Employees",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
