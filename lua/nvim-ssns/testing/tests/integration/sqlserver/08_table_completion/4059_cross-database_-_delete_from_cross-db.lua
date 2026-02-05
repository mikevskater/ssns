-- Test 4059: Cross-database - DELETE FROM cross-db

return {
  number = 4059,
  description = "Cross-database - DELETE FROM cross-db",
  database = "vim_dadbod_test",
  query = "DELETE FROM TEST.dbo.█",
  expected = {
    items = {
      includes_any = {
        "Records",
      },
    },
    type = "table",
  },
}
