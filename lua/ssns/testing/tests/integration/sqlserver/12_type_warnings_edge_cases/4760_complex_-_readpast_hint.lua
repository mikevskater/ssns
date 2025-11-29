-- Test 4760: Complex - READPAST hint

return {
  number = 4760,
  description = "Complex - READPAST hint",
  database = "vim_dadbod_test",
  query = "SELECT TOP 10 █ FROM Employees WITH (READPAST)",
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
