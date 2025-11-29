-- Test 4743: Complex - EXCEPT query columns

return {
  number = 4743,
  description = "Complex - EXCEPT query columns",
  database = "vim_dadbod_test",
  query = "SELECT █ FROM Employees EXCEPT SELECT EmployeeID FROM Employees WHERE IsActive = 0",
  expected = {
    items = {
      includes = {
        "EmployeeID",
      },
    },
    type = "column",
  },
}
