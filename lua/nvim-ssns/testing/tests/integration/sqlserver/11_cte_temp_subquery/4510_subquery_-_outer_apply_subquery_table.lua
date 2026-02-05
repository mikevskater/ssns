-- Test 4510: Subquery - OUTER APPLY subquery table

return {
  number = 4510,
  description = "Subquery - OUTER APPLY subquery table",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e OUTER APPLY (SELECT TOP 1 * FROM █) o",
  expected = {
    items = {
      includes = {
        "Orders",
      },
    },
    type = "table",
  },
}
