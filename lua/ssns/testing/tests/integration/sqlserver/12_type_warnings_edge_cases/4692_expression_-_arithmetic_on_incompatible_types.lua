-- Test 4692: Expression - arithmetic on incompatible types

return {
  number = 4692,
  description = "Expression - arithmetic on incompatible types",
  database = "vim_dadbod_test",
  query = "SELECT Salary + FirstName█ FROM Employees",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
        "invalid_operation",
      },
    },
    type = "warning",
  },
}
