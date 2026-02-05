-- Test 4665: Type compatibility - date = varchar (warning)
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4665,
  description = "Type compatibility - date = varchar (warning)",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
  query = "SELECT * FROM Projects WHERE StartDate = ProjectName█",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
