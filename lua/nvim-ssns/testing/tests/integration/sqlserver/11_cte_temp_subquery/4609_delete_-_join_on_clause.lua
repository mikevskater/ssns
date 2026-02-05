-- Test 4609: DELETE - JOIN ON clause
-- SKIPPED: Alias-qualified column completion in DELETE ON not yet supported

return {
  number = 4609,
  description = "DELETE - JOIN ON clause",
  database = "vim_dadbod_test",
  skip = false,
  query = "DELETE e FROM Employees e JOIN Departments d ON e.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
