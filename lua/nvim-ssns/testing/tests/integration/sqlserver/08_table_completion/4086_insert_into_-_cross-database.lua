-- Test 4086: INSERT INTO - cross-database

return {
  number = 4086,
  description = "INSERT INTO - cross-database",
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
