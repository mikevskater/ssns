-- Test 4384: ON clause - three-part name tables

return {
  number = 4384,
  description = "ON clause - three-part name tables",
  database = "vim_dadbod_test",
  skip = false,
  query = [[SELECT * FROM vim_dadbod_test.dbo.Employees e
JOIN vim_dadbod_test.dbo.Departments d ON e.DepartmentID = d.█]],
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
