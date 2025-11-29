-- Test 4794: Context - whitespace only

return {
  number = 4794,
  description = "Context - whitespace only",
  database = "vim_dadbod_test",
  query = "   █",
  expected = {
    items = {
      includes = {
        "SELECT",
      },
    },
    type = "keyword",
  },
}
