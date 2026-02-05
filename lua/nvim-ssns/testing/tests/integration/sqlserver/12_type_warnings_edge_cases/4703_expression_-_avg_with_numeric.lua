-- Test 4703: Expression - AVG with numeric

return {
  number = 4703,
  description = "Expression - AVG with numeric",
  database = "vim_dadbod_test",
  query = "SELECT AVG(Salary)█ FROM Employees",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
