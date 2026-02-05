-- Test 4006: FROM clause - prefix filter 'Emp'

return {
  number = 4006,
  description = "FROM clause - prefix filter 'Emp'",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Emp█",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
