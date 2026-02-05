-- Test 4058: Cross-database - UPDATE cross-db table

return {
  number = 4058,
  description = "Cross-database - UPDATE cross-db table",
  database = "vim_dadbod_test",
  query = "UPDATE TEST.dbo.█",
  expected = {
    items = {
      includes_any = {
        "Records",
      },
    },
    type = "table",
  },
}
