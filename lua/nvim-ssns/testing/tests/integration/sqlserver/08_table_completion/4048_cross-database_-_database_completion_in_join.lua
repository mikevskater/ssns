-- Test 4048: Cross-database - database completion in JOIN

return {
  number = 4048,
  description = "Cross-database - database completion in JOIN",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees e JOIN TEST.█",
  expected = {
    items = {
      includes = {
        "dbo",
      },
    },
    type = "schema",
  },
}
