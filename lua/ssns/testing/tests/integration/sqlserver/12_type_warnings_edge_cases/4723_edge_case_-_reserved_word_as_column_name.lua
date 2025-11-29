-- Test 4723: Edge case - reserved word as column name

return {
  number = 4723,
  description = "Edge case - reserved word as column name",
  database = "vim_dadbod_test",
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
