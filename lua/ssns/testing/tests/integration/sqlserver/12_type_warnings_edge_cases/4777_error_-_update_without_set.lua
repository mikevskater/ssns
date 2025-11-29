-- Test 4777: Error - UPDATE without SET

return {
  number = 4777,
  description = "Error - UPDATE without SET",
  database = "vim_dadbod_test",
  query = "UPDATE Employees WHERE EmployeeID = 1█",
  expected = {
    type = "error",
  },
}
