-- Test 4090: UPDATE - prefix filter

return {
  number = 4090,
  description = "UPDATE - prefix filter",
  database = "vim_dadbod_test",
  query = "UPDATE Emp█",
  expected = {
    items = {
      includes = {
        "Employees",
      },
    },
    type = "table",
  },
}
