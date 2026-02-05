-- Test 4780: Error - recursive CTE without UNION ALL
-- SKIPPED: Warning type completion not yet supported

return {
  number = 4780,
  description = "Error - recursive CTE without UNION ALL",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "Warning type completion not yet supported",
  query = "WITH RecCTE AS (SELECT * FROM Employees UNION SELECT * FROM RecCTE) SELECT * FROM RecCT█E",
  expected = {
    items = {
      includes_any = {
        "recursive_union",
      },
    },
    type = "warning",
  },
}
