-- Test 4694: Expression - CONCAT with mixed types

return {
  number = 4694,
  description = "Expression - CONCAT with mixed types",
  database = "vim_dadbod_test",
  query = "SELECT CONCAT(FirstName, EmployeeID) █FROM Employees",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
