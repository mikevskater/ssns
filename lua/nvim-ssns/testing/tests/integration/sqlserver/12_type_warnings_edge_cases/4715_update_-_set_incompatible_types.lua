-- Test 4715: UPDATE - SET incompatible types
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4715,
  description = "UPDATE - SET incompatible types",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
  query = "UPDATE Employees SET EmployeeID = 'text'█",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
        "conversion_error",
      },
    },
    type = "warning",
  },
}
