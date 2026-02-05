-- Test 4010: FROM clause - completion returns all tables (prefix filtering done by UI)
-- Note: Prefix filtering is handled by blink.cmp, not the completion source.
-- The source returns all available tables; the UI filters by typed prefix.

return {
  number = 4010,
  description = "FROM clause - completion returns all tables (prefix filtering done by UI)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM xyz_nonexistent█",
  expected = {
    items = {
      -- All tables returned; blink.cmp filters by prefix in real usage
      includes = {
        "Employees",
        "Departments",
      },
    },
    type = "table",
  },
}
