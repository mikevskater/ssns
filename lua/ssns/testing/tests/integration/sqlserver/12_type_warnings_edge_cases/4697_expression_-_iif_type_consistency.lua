-- Test 4697: Expression - IIF type consistency
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4697,
  description = "Expression - IIF type consistency",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
  query = "SELECT IIF(IsActive = 1, Salary, 'None') █FROM Employees",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
