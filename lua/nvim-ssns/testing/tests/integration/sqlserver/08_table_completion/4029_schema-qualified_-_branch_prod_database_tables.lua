-- Test 4029: Schema-qualified - Branch_Prod database tables

return {
  number = 4029,
  description = "Schema-qualified - Branch_Prod database tables",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Branch_Prod.dbo.█",
  expected = {
    items = {
      includes = {
        "central_division",
        "eastern_division",
        "western_division",
        "division_metrics",
        "vw_all_divisions",
      },
    },
    type = "table",
  },
}
