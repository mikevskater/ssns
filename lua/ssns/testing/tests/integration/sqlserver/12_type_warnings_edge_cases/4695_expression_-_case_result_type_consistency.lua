-- Test 4695: Expression - CASE result type consistency
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4695,
  description = "Expression - CASE result type consistency",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
  query = "SELECT CASE WHEN IsActive = 1 THEN Salary ELSE 'N/A' END █FROM Employees",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
        "case_type_inconsistency",
      },
    },
    type = "warning",
  },
}
