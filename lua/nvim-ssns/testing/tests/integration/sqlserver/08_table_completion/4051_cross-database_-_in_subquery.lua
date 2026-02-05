-- Test 4051: Cross-database - in subquery

return {
  number = 4051,
  description = "Cross-database - in subquery",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees WHERE DeptID IN (SELECT ID FROM TEST.dbo.█)",
  expected = {
    items = {
      includes_any = {
        "Records",
      },
    },
    type = "table",
  },
}
