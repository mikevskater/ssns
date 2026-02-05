-- Test 4691: Expression - arithmetic on compatible types

return {
  number = 4691,
  description = "Expression - arithmetic on compatible types",
  database = "vim_dadbod_test",
  query = "SELECT Salary + DepartmentID █FROM Employees",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
