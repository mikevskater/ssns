-- Test 4624: DELETE - cross-database

return {
  number = 4624,
  description = "DELETE - cross-database",
  database = "vim_dadbod_test",
  query = "DELETE FROM TEST.dbo.█",
  expected = {
    items = {
      includes_any = {
        "Records",
        "TestTable",
      },
    },
    type = "table",
  },
}
