-- Test 4043: Cross-database - schemas in other database

return {
  number = 4043,
  description = "Cross-database - schemas in other database",
  database = "vim_dadbod_test",
  query = "SELECT * FROM TEST.█",
  expected = {
    items = {
      includes = {
        "dbo",
      },
    },
    type = "schema",
  },
}
