-- Test 4050: Cross-database - master database system tables
-- Access system views in master database

return {
  number = 4050,
  description = "Cross-database - master database system tables",
  database = "vim_dadbod_test",
  query = "SELECT * FROM master.sys.█",
  expected = {
    items = {
      includes_any = {
        "databases",
        "objects",
        "tables",
      },
    },
    type = "table",
  },
}
