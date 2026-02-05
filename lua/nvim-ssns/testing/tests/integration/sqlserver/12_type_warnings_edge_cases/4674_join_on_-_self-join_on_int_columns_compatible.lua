-- Test 4674: JOIN ON - self-join on int columns (compatible)

return {
  number = 4674,
  description = "JOIN ON - self-join on int columns (compatible)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Employees m ON e.DepartmentID = m.Employe█eID",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
