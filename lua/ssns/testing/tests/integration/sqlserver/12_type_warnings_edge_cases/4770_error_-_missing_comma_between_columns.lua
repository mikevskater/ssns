-- Test 4770: Error - missing comma between columns

return {
  number = 4770,
  description = "Error - missing comma between columns",
  database = "vim_dadbod_test",
  query = "SELECT EmployeeID FirstName █FROM Employees",
  expected = {
    items = {
      valid = true,
    },
    type = "valid",
  },
}
