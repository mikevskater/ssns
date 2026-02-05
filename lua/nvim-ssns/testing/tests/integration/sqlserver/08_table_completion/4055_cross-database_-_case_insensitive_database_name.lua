-- Test 4055: Cross-database - case insensitive database name

return {
  number = 4055,
  description = "Cross-database - case insensitive database name",
  database = "vim_dadbod_test",
  query = "SELECT * FROM test.█",
  expected = {
    items = {
      includes = {
        "dbo",
      },
    },
    type = "schema",
  },
}
