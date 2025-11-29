-- Test 4683: JOIN ON - varchar length difference

return {
  number = 4683,
  description = "JOIN ON - varchar length difference",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.Email = d.DepartmentName█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
