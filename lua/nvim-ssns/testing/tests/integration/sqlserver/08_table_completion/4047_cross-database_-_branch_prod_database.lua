-- Test 4047: Cross-database - Branch_Prod database

return {
  number = 4047,
  description = "Cross-database - Branch_Prod database",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Branch_Prod.█",
  expected = {
    items = {
      includes = {
        "dbo",
      },
    },
    type = "schema",
  },
}
