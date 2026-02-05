-- Test 4791: Context - cursor at very start of query

return {
  number = 4791,
  description = "Context - cursor at very start of query",
  database = "vim_dadbod_test",
  query = "█ FROM Employees",
  expected = {
    items = {
      includes_any = {
        "SELECT",
        "INSERT",
        "UPDATE",
        "DELETE",
      },
    },
    type = "keyword",
  },
}
