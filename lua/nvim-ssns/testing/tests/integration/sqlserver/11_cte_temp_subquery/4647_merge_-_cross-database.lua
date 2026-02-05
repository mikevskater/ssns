-- Test 4647: MERGE - cross-database
-- SKIPPED: Cross-database completion not yet supported

return {
  number = 4647,
  description = "MERGE - cross-database",
  database = "vim_dadbod_test",
  skip = false,
  query = [[MERGE INTO vim_dadbod_test.dbo.Employees AS target
USING TEST.dbo.█ AS source
ON target.EmployeeID = source.EmployeeID]],
  expected = {
    items = {
      includes_any = {
        "Records",
        "syn_MainEmployees",
      },
    },
    type = "table",
  },
}
