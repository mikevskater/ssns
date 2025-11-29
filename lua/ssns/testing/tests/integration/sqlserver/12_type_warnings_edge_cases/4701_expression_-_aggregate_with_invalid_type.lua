-- Test 4701: Expression - aggregate with invalid type

return {
  number = 4701,
  description = "Expression - aggregate with invalid type",
  database = "vim_dadbod_test",
  query = "SELECT SUM(FirstName)█ FROM Employees",
  expected = {
    items = {
      includes_any = {
        "invalid_aggregate",
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
