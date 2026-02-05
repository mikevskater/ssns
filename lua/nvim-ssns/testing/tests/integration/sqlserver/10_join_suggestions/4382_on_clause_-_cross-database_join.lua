-- Test 4382: ON clause - cross-database join
-- SKIPPED: Cross-database join column completion not yet supported

return {
  number = 4382,
  description = "ON clause - cross-database join",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Test table TEST.dbo.Records does not exist in database",
  query = [[SELECT * FROM vim_dadbod_test.dbo.Employees e
JOIN TEST.dbo.Records r ON e.EmployeeID = r.█]],
  expected = {
    items = {
      includes_any = {
        "id",
        "name",
      },
    },
    type = "column",
  },
}
