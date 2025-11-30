-- Test 4774: Error - HAVING without GROUP BY
-- SKIPPED: HAVING clause aggregate function completion not yet supported

return {
  number = 4774,
  description = "Error - HAVING without GROUP BY",
  database = "vim_dadbod_test",
  skip = true,
  skip_reason = "HAVING clause aggregate function completion not yet supported",
  query = "SELECT * FROM Employees HAVING █ > 0",
  expected = {
    items = {
      includes_any = {
        "COUNT",
        "SUM",
      },
    },
    type = "column",
  },
}
