-- Test 4014: FROM clause - second table with prefix

return {
  number = 4014,
  description = "FROM clause - second table with prefix",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Employees, Dep█",
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
