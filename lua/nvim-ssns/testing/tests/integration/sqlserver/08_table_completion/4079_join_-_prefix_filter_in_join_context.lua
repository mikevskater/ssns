-- Test 4079: JOIN - tables available in JOIN context with prefix
-- Note: Prefix filtering is handled by blink.cmp, not the completion source.
-- The source returns all tables; the UI filters by typed prefix.

return {
  number = 4079,
  description = "JOIN - tables available in JOIN context with prefix",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Dep█",
  expected = {
    items = {
      -- All tables returned; blink.cmp filters by "Dep" prefix in real usage
      includes = {
        "Departments",
        "Employees",
      },
    },
    type = "table",
  },
}
