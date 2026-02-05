-- Test 4497: Temp table - ALTER TABLE
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4497,
  description = "Temp table - ALTER TABLE",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (ID INT)
ALTER TABLE █]],
  expected = {
    items = {
      includes = {
        "#TempEmployees",
        "Employees",
      },
    },
    type = "table",
  },
}
