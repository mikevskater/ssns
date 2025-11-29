-- Test 4119: SELECT - schema.table with alias

return {
  number = 4119,
  description = "SELECT - schema.table with alias",
  database = "vim_dadbod_test",
  query = "SELECT e.█ FROM dbo.Employees e",
  expected = {
    items = {
      includes = {
        "EmployeeID",
        "FirstName",
      },
    },
    type = "column",
  },
}
