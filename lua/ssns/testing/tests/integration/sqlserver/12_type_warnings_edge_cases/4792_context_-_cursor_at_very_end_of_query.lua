-- Test 4792: Context - cursor at very end of query

return {
  number = 4792,
  description = "Context - cursor at very end of query",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE EmployeeID = 1 █",
  expected = {
    items = {
      includes_any = {
        "AND",
        "OR",
        "ORDER BY",
      },
    },
    type = "keyword",
  },
}
