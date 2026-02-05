-- Test 4378: ON clause - parenthesized conditions

return {
  number = 4378,
  description = "ON clause - parenthesized conditions",
  database = "vim_dadbod_test",
  skip = false,
  query = [[SELECT * FROM Employees e
JOIN Departments d ON (e.DepartmentID = d.DepartmentID) AND (e.Salary = d.█]],
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
