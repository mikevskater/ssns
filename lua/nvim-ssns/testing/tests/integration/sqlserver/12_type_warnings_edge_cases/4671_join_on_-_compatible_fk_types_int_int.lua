-- Test 4671: JOIN ON - compatible FK types (int = int)

return {
  number = 4671,
  description = "JOIN ON - compatible FK types (int = int)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.DepartmentI█D",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
