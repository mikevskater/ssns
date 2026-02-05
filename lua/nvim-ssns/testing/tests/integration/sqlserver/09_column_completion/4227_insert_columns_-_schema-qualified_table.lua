-- Test 4227: INSERT columns - schema-qualified table

return {
  number = 4227,
  description = "INSERT columns - schema-qualified table",
  database = "vim_dadbod_test",
  query = "INSERT INTO dbo.Employees (█",
  expected = {
    items = {
      includes = {
        "FirstName",
        "LastName",
      },
    },
    type = "column",
  },
}
