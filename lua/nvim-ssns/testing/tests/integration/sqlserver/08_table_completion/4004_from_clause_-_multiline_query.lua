-- Test 4004: FROM clause - multiline query

return {
  number = 4004,
  description = "FROM clause - multiline query",
  database = "vim_dadbod_test",
  query = [[SELECT
  *
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
