-- Test 4680: JOIN ON - explicit collation

return {
  number = 4680,
  description = "JOIN ON - explicit collation",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.FirstName COLLATE Latin1_General_CI_AS = d.DepartmentN█ame",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
