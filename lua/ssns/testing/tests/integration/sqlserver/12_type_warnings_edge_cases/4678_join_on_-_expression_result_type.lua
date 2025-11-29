-- Test 4678: JOIN ON - expression result type

return {
  number = 4678,
  description = "JOIN ON - expression result type",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentID + █0",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
