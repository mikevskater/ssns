-- Test 4102: SELECT - columns with prefix filter
-- Note: Prefix filtering is done by blink.cmp UI, not completion source.
-- Completion source returns all columns; UI filters by prefix.

return {
  number = 4102,
  description = "SELECT - columns with prefix filter",
  database = "vim_dadbod_test",
  query = "SELECT First█ FROM Employees",
  expected = {
    items = {
      includes = {
        "FirstName",
      },
    },
    type = "column",
  },
}
