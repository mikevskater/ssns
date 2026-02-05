-- Test 4132: WHERE - column with prefix
-- Note: Prefix filtering is done by blink.cmp UI, not completion source.

return {
  number = 4132,
  description = "WHERE - column with prefix",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE First█",
  expected = {
    items = {
      includes = {
        "FirstName",
      },
    },
    type = "column",
  },
}
