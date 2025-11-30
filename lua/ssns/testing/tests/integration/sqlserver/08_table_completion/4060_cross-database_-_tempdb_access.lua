-- Test 4060: Cross-database - tempdb access
-- Access system views in tempdb database

return {
  number = 4060,
  description = "Cross-database - tempdb access",
  database = "vim_dadbod_test",
  query = "SELECT * FROM tempdb.sys.█",
  expected = {
    items = {
      includes_any = {
        "all_objects",
        "all_views",
        "columns",
      },
    },
    type = "table",
  },
}
