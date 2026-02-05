-- Test 4567: INSERT - cross-database table

return {
  number = 4567,
  description = "INSERT - cross-database table",
  database = "vim_dadbod_test",
  query = "INSERT INTO TEST.dbo.█ SELECT * FROM Employees",
  expected = {
    items = {
      includes_any = {
        "Records",
        "TestTable",
      },
    },
    type = "table",
  },
}
