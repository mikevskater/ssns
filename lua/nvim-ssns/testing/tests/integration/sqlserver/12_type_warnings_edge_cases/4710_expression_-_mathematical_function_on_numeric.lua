-- Test 4710: Expression - mathematical function on numeric

return {
  number = 4710,
  description = "Expression - mathematical function on numeric",
  database = "vim_dadbod_test",
  query = "SELECT SQRT(Salary)█ FROM Employees",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
