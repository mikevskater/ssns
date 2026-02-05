-- Test 4002: FROM clause - views should be included

return {
  number = 4002,
  description = "FROM clause - views should be included",
  database = "vim_dadbod_test",
  query = "SELECT * FROM █",
  expected = {
    items = {
      includes = {
        "vw_ActiveEmployees",
        "vw_DepartmentSummary",
        "vw_ProjectStatus",
      },
    },
    type = "table",
  },
}
