-- Test 4552: INSERT - schema-qualified table

return {
  number = 4552,
  description = "INSERT - schema-qualified table",
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
