-- Test 4089: UPDATE - schema-qualified

return {
  number = 4089,
  description = "UPDATE - schema-qualified",
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
