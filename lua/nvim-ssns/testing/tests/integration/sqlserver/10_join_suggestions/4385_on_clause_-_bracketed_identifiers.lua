-- Test 4385: ON clause - bracketed identifiers
-- SKIPPED: Bracketed column name in ON clause context detection not yet supported

return {
  number = 4385,
  description = "ON clause - bracketed identifiers",
  database = "vim_dadbod_test",
  skip = false,
  query = "SELECT * FROM [Employees] e JOIN [Departments] d ON e.[DepartmentID] = d.█",
  expected = {
    items = {
      includes = {
        "DepartmentID",
      },
    },
    type = "column",
  },
}
