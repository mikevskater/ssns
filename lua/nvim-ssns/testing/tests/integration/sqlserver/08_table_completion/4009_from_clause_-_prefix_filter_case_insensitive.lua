-- Test 4009: FROM clause - prefix filter case insensitive

return {
  number = 4009,
  description = "FROM clause - prefix filter case insensitive",
  database = "vim_dadbod_test",
  query = "SELECT * FROM emp█",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
