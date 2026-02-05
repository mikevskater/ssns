-- Test 4095: DELETE FROM - schema-qualified

return {
  number = 4095,
  description = "DELETE FROM - schema-qualified",
  database = "vim_dadbod_test",
  query = "DELETE FROM dbo.█",
  expected = {
    items = {
      includes = {
        "Employees",
        "Departments",
      },
    },
    type = "table",
  },
}
