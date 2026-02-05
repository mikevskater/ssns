-- Test 4682: JOIN ON - bit to int comparison

return {
  number = 4682,
  description = "JOIN ON - bit to int comparison",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.IsActive = d.DepartmentID█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
