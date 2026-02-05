-- Test 4039: Schema-qualified - UPDATE statement

return {
  number = 4039,
  description = "Schema-qualified - UPDATE statement",
  database = "vim_dadbod_test",
  query = "UPDATE dbo.█",
  expected = {
    items = {
      excludes = {
        "vw_ActiveEmployees",
      },
      includes = {
        "Employees",
        "Departments",
      },
    },
    type = "table",
  },
}
