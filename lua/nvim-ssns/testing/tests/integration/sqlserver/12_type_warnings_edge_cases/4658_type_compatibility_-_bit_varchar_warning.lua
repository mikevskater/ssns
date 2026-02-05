-- Test 4658: Type compatibility - bit = varchar (warning)
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4658,
  description = "Type compatibility - bit = varchar (warning)",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
  query = "SELECT * FROM Employees WHERE IsActive = FirstNa█me",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
