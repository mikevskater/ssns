-- Test 4025: Schema-qualified - views in schema

return {
  number = 4025,
  description = "Schema-qualified - views in schema",
  database = "vim_dadbod_test",
  query = "SELECT * FROM dbo.vw_█",
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
