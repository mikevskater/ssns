-- Test 4046: Cross-database - bracketed database and schema

return {
  number = 4046,
  description = "Cross-database - bracketed database and schema",
  database = "vim_dadbod_test",
  query = "SELECT * FROM [TEST].[dbo].█",
  expected = {
    items = {
      includes_any = {
        "Records",
      },
    },
    type = "table",
  },
}
