-- Test 4654: Type compatibility - date = int (warning)
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4654,
  description = "Type compatibility - date = int (warning)",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
  query = "SELECT * FROM Employees WHERE HireDate = Employee█ID",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
