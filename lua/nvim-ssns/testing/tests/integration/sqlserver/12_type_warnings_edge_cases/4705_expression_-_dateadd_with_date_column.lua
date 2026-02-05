-- Test 4705: Expression - DATEADD with date column

return {
  number = 4705,
  description = "Expression - DATEADD with date column",
  database = "vim_dadbod_test",
  query = "SELECT DATEADD(day, 30, HireDate) █FROM Employees",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
