-- Test 4774: Error - HAVING without GROUP BY

return {
  number = 4774,
  description = "Error - HAVING without GROUP BY",
  database = "vim_dadbod_test",
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
