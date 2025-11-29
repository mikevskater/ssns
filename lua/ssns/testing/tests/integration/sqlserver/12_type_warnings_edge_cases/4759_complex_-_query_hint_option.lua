-- Test 4759: Complex - query hint OPTION

return {
  number = 4759,
  description = "Complex - query hint OPTION",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM Employees OPTION (MAXDOP 1)",
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
