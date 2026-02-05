-- Test 4795: Context - comment only

return {
  number = 4795,
  description = "Context - comment only",
  database = "vim_dadbod_test",
  query = [[-- This is a comment
█]],
  expected = {
    items = {
      includes = {
        "SELECT",
      },
    },
    type = "keyword",
  },
}
