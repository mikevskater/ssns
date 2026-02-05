-- Test 4080: JOIN - cross-database in JOIN

return {
  number = 4080,
  description = "JOIN - cross-database in JOIN",
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
