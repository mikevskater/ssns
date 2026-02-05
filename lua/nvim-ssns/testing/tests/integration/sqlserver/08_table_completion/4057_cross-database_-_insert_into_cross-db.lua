-- Test 4057: Cross-database - INSERT INTO cross-db

return {
  number = 4057,
  description = "Cross-database - INSERT INTO cross-db",
  database = "vim_dadbod_test",
  query = "INSERT INTO TEST.dbo.█",
  expected = {
    items = {
      includes_any = {
        "Records",
      },
    },
    type = "table",
  },
}
