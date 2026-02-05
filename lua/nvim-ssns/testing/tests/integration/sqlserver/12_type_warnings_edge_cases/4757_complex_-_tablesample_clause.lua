-- Test 4757: Complex - TABLESAMPLE clause

return {
  number = 4757,
  description = "Complex - TABLESAMPLE clause",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM Employees TABLESAMPLE (10 PERCENT)",
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
