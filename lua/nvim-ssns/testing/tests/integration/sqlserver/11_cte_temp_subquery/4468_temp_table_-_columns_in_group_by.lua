-- Test 4468: Temp table - columns in GROUP BY
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4468,
  description = "Temp table - columns in GROUP BY",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #TempEmployees (ID INT, DeptID INT, Salary DECIMAL(10,2))
SELECT DeptID, SUM(Salary) FROM #TempEmployees GROUP BY █]],
  expected = {
    items = {
      includes = {
        "DeptID",
      },
    },
    type = "column",
  },
}
