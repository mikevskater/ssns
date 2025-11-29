-- Test 4704: Expression - AVG with non-numeric

return {
  number = 4704,
  description = "Expression - AVG with non-numeric",
  database = "vim_dadbod_test",
  query = "SELECT AVG(FirstName)█ FROM Employees",
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
