-- Test 4666: Type compatibility - decimal = varchar (warning)
-- SKIPPED: Type warning/compatibility checks not yet supported

return {
  number = 4666,
  description = "Type compatibility - decimal = varchar (warning)",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Type warning/compatibility checks not yet supported",
  query = "SELECT * FROM Projects WHERE Budget = ProjectName█",
  expected = {
    items = {
      includes_any = {
        "type_mismatch",
      },
    },
    type = "warning",
  },
}
