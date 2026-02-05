-- Test 4341: FK suggestion - preserves schema in insertText

return {
  number = 4341,
  description = "FK suggestion - preserves schema in insertText",
  database = "vim_dadbod_test",
  query = "SELECT * FROM hr.Benefits b JOIN █",
  expected = {
    items = {
      includes_any = {
        "Employees",
      },
    },
    type = "join_suggestion",
  },
}
