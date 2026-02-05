-- Test 4455: Temp table - SELECT INTO creates temp table
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4455,
  description = "Temp table - SELECT INTO creates temp table",
  database = "vim_dadbod_test",
  skip = false,
  query = [[SELECT * INTO #TempResult FROM Employees
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "#TempResult",
        "Employees",
      },
    },
    type = "table",
  },
}
