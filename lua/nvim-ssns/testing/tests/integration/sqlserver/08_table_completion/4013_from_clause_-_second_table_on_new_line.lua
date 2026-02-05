-- Test 4013: FROM clause - second table on new line

return {
  number = 4013,
  description = "FROM clause - second table on new line",
  database = "vim_dadbod_test",
  query = [[SELECT * FROM Employees,
  █]],
  expected = {
    items = {
      includes = {
        "Departments",
      },
    },
    type = "table",
  },
}
