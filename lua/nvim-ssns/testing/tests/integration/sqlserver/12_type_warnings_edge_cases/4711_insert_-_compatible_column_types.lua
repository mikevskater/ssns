-- Test 4711: INSERT - compatible column types

return {
  number = 4711,
  description = "INSERT - compatible column types",
  database = "vim_dadbod_test",
  query = "INSERT INTO Employees (EmployeeID, FirstName) VALUES (1, 'John█')",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
