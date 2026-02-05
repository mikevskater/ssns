-- Test 4376: ON clause - compound condition with AND

return {
  number = 4376,
  description = "ON clause - compound condition with AND",
  database = "vim_dadbod_test",
  skip = false,
  query = [[SELECT * FROM Employees e
JOIN Departments d ON e.DepartmentID = d.DepartmentID AND e.Salary = d.█]],
  expected = {
    items = {
      includes_any = {
        "Budget",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
