-- Test 4082: INSERT INTO - schema-qualified

return {
  number = 4082,
  description = "INSERT INTO - schema-qualified",
  database = "vim_dadbod_test",
  query = "INSERT INTO dbo.█",
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
