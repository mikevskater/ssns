-- Test 4075: JOIN - schema-qualified FK suggestion

return {
  number = 4075,
  description = "JOIN - schema-qualified FK suggestion",
  database = "vim_dadbod_test",
  query = "SELECT * FROM dbo.Employees e JOIN dbo.█",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
