-- Test 4049: Cross-database - full three-part name completion

return {
  number = 4049,
  description = "Cross-database - full three-part name completion",
  database = "vim_dadbod_test",
  query = "SELECT * FROM TEST.dbo.R█",
  expected = {
    items = {
      includes_any = {
        "Records",
      },
    },
    type = "table",
  },
}
