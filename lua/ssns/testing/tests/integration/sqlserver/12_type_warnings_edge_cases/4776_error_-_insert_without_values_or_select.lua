-- Test 4776: Error - INSERT without VALUES or SELECT

return {
  number = 4776,
  description = "Error - INSERT without VALUES or SELECT",
  database = "vim_dadbod_test",
  query = "INSERT INTO Employees (EmployeeID)█",
  expected = {
    type = "error",
  },
}
