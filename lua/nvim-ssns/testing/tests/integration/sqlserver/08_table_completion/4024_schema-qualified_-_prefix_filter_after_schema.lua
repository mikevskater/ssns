-- Test 4024: Schema-qualified - tables in dbo schema with prefix
-- Note: Prefix filtering is handled by blink.cmp, not the completion source.
-- The source returns all tables in schema; the UI filters by typed prefix.

return {
  number = 4024,
  description = "Schema-qualified - tables in dbo schema with prefix",
  database = "vim_dadbod_test",
  query = "SELECT * FROM dbo.Emp█",
  expected = {
    items = {
      -- All dbo tables returned; blink.cmp filters by "Emp" prefix in real usage
      includes = {
        "Employees",
        "Departments",
      },
    },
    type = "table",
  },
}
