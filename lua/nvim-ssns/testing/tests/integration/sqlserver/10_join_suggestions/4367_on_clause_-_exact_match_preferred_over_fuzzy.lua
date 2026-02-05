-- Test 4367: ON clause - exact match preferred over fuzzy

return {
  number = 4367,
  description = "ON clause - exact match preferred over fuzzy",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN Departments d ON e.DepartmentID = d.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
