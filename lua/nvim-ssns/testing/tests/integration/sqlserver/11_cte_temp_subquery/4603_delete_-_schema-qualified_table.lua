-- Test 4603: DELETE - schema-qualified table

return {
  number = 4603,
  description = "DELETE - schema-qualified table",
  database = "vim_dadbod_test",
  query = "DELETE FROM dbo.█",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
