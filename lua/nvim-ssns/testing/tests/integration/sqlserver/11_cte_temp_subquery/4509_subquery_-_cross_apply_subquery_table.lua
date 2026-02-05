-- Test 4509: Subquery - CROSS APPLY subquery table

return {
  number = 4509,
  description = "Subquery - CROSS APPLY subquery table",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Departments d CROSS APPLY (SELECT TOP 5 * FROM █) x",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
