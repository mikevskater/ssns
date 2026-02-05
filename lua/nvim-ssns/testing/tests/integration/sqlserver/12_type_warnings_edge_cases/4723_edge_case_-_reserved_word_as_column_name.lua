-- Test 4723: Edge case - reserved word as column name
-- SKIPPED: Test table does not exist in database

return {
  number = 4723,
  description = "Edge case - reserved word as column name",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Test table does not exist in database",
  query = "SELECT [select], [from], [where]█ FROM ReservedTable",
  expected = {
    items = {
      includes_any = {
        "select",
        "from",
        "where",
      },
    },
    type = "column",
  },
}
