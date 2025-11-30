-- Test 4699: Expression - NULLIF incompatible types
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4699,
  description = "Expression - NULLIF incompatible types",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
  query = "SELECT NULLIF(EmployeeID, FirstName) █FROM Employees",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
