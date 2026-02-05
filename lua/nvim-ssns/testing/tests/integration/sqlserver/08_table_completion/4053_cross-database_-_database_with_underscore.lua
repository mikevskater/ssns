-- Test 4053: Cross-database - database with underscore

return {
  number = 4053,
  description = "Cross-database - database with underscore",
  database = "vim_dadbod_test",
  query = "SELECT * FROM vim_dadbod_test.█",
  expected = {
    items = {
      includes = {
        "dbo",
        "hr",
      },
    },
    type = "schema",
  },
}
