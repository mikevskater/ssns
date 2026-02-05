-- Test 4696: Expression - COALESCE type consistency
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4696,
  description = "Expression - COALESCE type consistency",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
  query = "SELECT COALESCE(DepartmentID, FirstName) F█ROM Employees",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
