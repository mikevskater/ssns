-- Test 4572: UPDATE - schema-qualified table

return {
  number = 4572,
  description = "UPDATE - schema-qualified table",
  database = "vim_dadbod_test",
  query = "UPDATE dbo.█",
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
