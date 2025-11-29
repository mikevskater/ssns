-- Test 4118: SELECT - long alias name

return {
  number = 4118,
  description = "SELECT - long alias name",
  database = "vim_dadbod_test",
  query = "SELECT employees_table.█ FROM Employees employees_table",
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
