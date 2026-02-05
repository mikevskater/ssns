-- Test 4312: FK suggestion - schema-qualified source table

return {
  number = 4312,
  description = "FK suggestion - schema-qualified source table",
  database = "vim_dadbod_test",
  query = "SELECT * FROM dbo.Employees e JOIN █",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "join_suggestion",
  },
}
