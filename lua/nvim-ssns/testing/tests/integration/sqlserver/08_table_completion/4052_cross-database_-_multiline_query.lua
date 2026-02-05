-- Test 4052: Cross-database - multiline query

return {
  number = 4052,
  description = "Cross-database - multiline query",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM vim_dadbod_test.dbo.Employees e
JOIN TEST.dbo.█]],
  expected = {
    items = {
      includes_any = {
        "Records",
      },
    },
    type = "table",
  },
}
