-- Test 4045: Cross-database - bracketed database name

return {
  number = 4045,
  description = "Cross-database - bracketed database name",
  database = "vim_dadbod_test",
  query = "SELECT * FROM [TEST].█",
  expected = {
    items = {
      includes = {
        "dbo",
      },
    },
    type = "schema",
  },
}
