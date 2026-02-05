-- Test 4044: Cross-database - tables after database.schema.

return {
  number = 4044,
  description = "Cross-database - tables after database.schema.",
  database = "vim_dadbod_test",
  query = "SELECT * FROM TEST.dbo.█",
  expected = {
    items = {
      includes_any = {
        "Records",
        "syn_MainEmployees",
      },
    },
    type = "table",
  },
}
