-- Test 4005: FROM clause - after newline with space

return {
  number = 4005,
  description = "FROM clause - after newline with space",
  database = "vim_dadbod_test",
  query = [[SELECT *
FROM █]],
  expected = {
    items = {
      includes = {
        "Employees",
        "Departments",
      },
    },
    type = "table",
  },
}
