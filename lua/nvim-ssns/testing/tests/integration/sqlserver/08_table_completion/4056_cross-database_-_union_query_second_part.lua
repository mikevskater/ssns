-- Test 4056: Cross-database - UNION query second part

return {
  number = 4056,
  description = "Cross-database - UNION query second part",
  database = "vim_dadbod_test",
  query = [[SELECT * FROM Employees
UNION ALL
SELECT * FROM TEST.dbo.█]],
  expected = {
    items = {
      includes_any = {
        "Records",
      },
    },
    type = "table",
  },
}
