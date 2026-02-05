-- Test 4007: FROM clause - prefix filter 'vw_'

return {
  number = 4007,
  description = "FROM clause - prefix filter 'vw_'",
  database = "vim_dadbod_test",
  query = "SELECT * FROM vw_█",
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
