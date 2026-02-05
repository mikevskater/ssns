-- Test 4340: Complex scenario - cross-database JOIN

return {
  number = 4340,
  description = "Complex scenario - cross-database JOIN",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN TEST.dbo.█",
  expected = {
    items = {
      includes_any = {
        "Records",
      },
    },
    type = "table",
  },
}
