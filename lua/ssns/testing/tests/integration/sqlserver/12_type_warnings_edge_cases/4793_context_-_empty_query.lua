-- Test 4793: Context - empty query

return {
  number = 4793,
  description = "Context - empty query",
  database = "vim_dadbod_test",
  query = "█",
  expected = {
    items = {
      includes = {
        "SELECT",
        "INSERT",
        "UPDATE",
        "DELETE",
        "WITH",
      },
    },
    type = "keyword",
  },
}
