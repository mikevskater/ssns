-- Test 4706: Expression - DATEADD with non-date column
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4706,
  description = "Expression - DATEADD with non-date column",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
  query = "SELECT DATEADD(day, 30, FirstName) █FROM Employees",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
        "invalid_argument",
      },
    },
    type = "warning",
  },
}
