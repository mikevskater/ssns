-- Test 4692: Expression - arithmetic on incompatible types
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4692,
  description = "Expression - arithmetic on incompatible types",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
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
