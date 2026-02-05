-- Test 4698: Expression - NULLIF compatible types

return {
  number = 4698,
  description = "Expression - NULLIF compatible types",
  database = "vim_dadbod_test",
  query = "SELECT NULLIF(EmployeeID, DepartmentID) █FROM Employees",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
