-- Test 4042: Cross-database - after typing database prefix

return {
  number = 4042,
  description = "Cross-database - after typing database prefix",
  database = "vim_dadbod_test",
  query = "SELECT * FROM TEST█",
  expected = {
    items = {
      includes = {
        "TEST",
      },
    },
    type = "database",
  },
}
